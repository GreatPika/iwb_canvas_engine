import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/nodes.dart';
import '../../core/scene_spatial_index.dart';
import '../input/slices/commands/scene_commands_v2.dart';
import '../input/slices/draw/draw_slice.dart';
import '../input/slices/grid/grid_slice.dart';
import '../input/slices/move/move_slice.dart';
import '../input/slices/repaint/repaint_slice.dart';
import '../input/slices/selection/selection_slice.dart';
import '../input/slices/signals/signal_event.dart';
import '../input/slices/signals/signals_slice.dart';
import '../input/slices/spatial_index/spatial_index_slice.dart';
import '../model/document.dart';
import '../model/document_clone.dart';
import '../public/snapshot.dart' hide NodeId;
import 'change_set.dart';
import 'scene_writer.dart';
import 'store.dart';
import 'txn_context.dart';

class SceneControllerV2 extends ChangeNotifier {
  SceneControllerV2({SceneSnapshot? initialSnapshot})
    : _store = V2Store(
        sceneDoc: txnSceneFromSnapshot(initialSnapshot ?? SceneSnapshot()),
      );

  final V2Store _store;

  final V2SelectionSlice _selectionSlice = V2SelectionSlice();
  final V2GridSlice _gridSlice = V2GridSlice();
  final V2SpatialIndexSlice _spatialIndexSlice = V2SpatialIndexSlice();
  final V2SignalsSlice _signalsSlice = V2SignalsSlice();
  final V2RepaintSlice _repaintSlice = V2RepaintSlice();

  bool _writeInProgress = false;
  List<String> _debugLastCommitPhases = const <String>[];
  ChangeSet _debugLastChangeSet = ChangeSet();

  late final V2SceneCommandsSlice commands = V2SceneCommandsSlice(write);
  late final V2MoveSlice move = V2MoveSlice(write);
  late final V2DrawSlice draw = V2DrawSlice(write);

  SceneSnapshot get snapshot => txnSceneToSnapshot(_store.sceneDoc);
  Set<NodeId> get selectedNodeIds =>
      Set<NodeId>.unmodifiable(_store.selectedNodeIds);

  int get controllerEpoch => _store.controllerEpoch;
  int get structuralRevision => _store.structuralRevision;
  int get boundsRevision => _store.boundsRevision;
  int get visualRevision => _store.visualRevision;

  Stream<V2CommittedSignal> get signals => _signalsSlice.signals;

  @visibleForTesting
  List<String> get debugLastCommitPhases => _debugLastCommitPhases;

  @visibleForTesting
  ChangeSet get debugLastChangeSet => _debugLastChangeSet.txnClone();

  @visibleForTesting
  int get debugSpatialIndexBuildCount => _spatialIndexSlice.debugBuildCount;

  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) {
    return _spatialIndexSlice.writeQueryCandidates(
      scene: _store.sceneDoc,
      worldBounds: worldBounds,
      controllerEpoch: _store.controllerEpoch,
      boundsRevision: _store.boundsRevision,
    );
  }

  SceneNode? resolveSpatialCandidateNode(SceneSpatialCandidate candidate) {
    final layerIndex = candidate.layerIndex;
    if (layerIndex < 0 || layerIndex >= _store.sceneDoc.layers.length) {
      return null;
    }

    final layer = _store.sceneDoc.layers[layerIndex];
    if (layer.isBackground) {
      return null;
    }

    final nodeIndex = candidate.nodeIndex;
    if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
      return null;
    }

    final node = layer.nodes[nodeIndex];
    if (identical(node, candidate.node)) {
      return node;
    }

    // v2 write() commits always swap sceneDoc with a cloned document, so node
    // identity may differ after non-geometry writes while index coordinates
    // remain valid.
    if (node.id != candidate.node.id || node.type != candidate.node.type) {
      return null;
    }
    return node;
  }

  T write<T>(T Function(SceneWriter writer) fn) {
    if (_writeInProgress) {
      throw StateError('Nested write(...) calls are not allowed.');
    }

    _writeInProgress = true;
    final ctx = TxnContext(
      workingScene: txnCloneScene(_store.sceneDoc),
      workingSelection: Set<NodeId>.from(_store.selectedNodeIds),
      workingNodeIds: Set<NodeId>.from(_store.allNodeIds),
      nodeIdSeed: _store.nodeIdSeed,
    );

    try {
      final writer = SceneWriter(
        ctx,
        txnSignalSink: _signalsSlice.writeBufferSignal,
      );
      final result = fn(writer);
      _txnWriteCommit(ctx);
      return result;
    } catch (_) {
      _signalsSlice.writeDiscardBuffered();
      _repaintSlice.writeDiscardPending();
      rethrow;
    } finally {
      _writeInProgress = false;
    }
  }

  void writeReplaceScene(SceneSnapshot snapshot) {
    write<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }

  void _txnWriteCommit(TxnContext ctx) {
    var commitPhases = const <String>[];

    final selectionResult = _selectionSlice.writeNormalizeSelection(
      rawSelection: ctx.workingSelection,
      scene: ctx.workingScene,
    );
    commitPhases = <String>[...commitPhases, 'selection'];
    if (selectionResult.normalizedChanged) {
      ctx.changeSet.txnMarkSelectionChanged();
    }
    ctx.workingSelection = selectionResult.normalized;

    final gridChanged = _gridSlice.writeNormalizeGrid(scene: ctx.workingScene);
    commitPhases = <String>[...commitPhases, 'grid'];
    if (gridChanged) {
      ctx.changeSet.txnMarkGridChanged();
    }

    final nextEpoch =
        _store.controllerEpoch + (ctx.changeSet.documentReplaced ? 1 : 0);
    final nextStructuralRevision =
        _store.structuralRevision + (ctx.changeSet.structuralChanged ? 1 : 0);
    final nextBoundsRevision =
        _store.boundsRevision + (ctx.changeSet.boundsChanged ? 1 : 0);

    final shouldBumpVisual =
        ctx.changeSet.visualChanged ||
        ctx.changeSet.selectionChanged ||
        ctx.changeSet.gridChanged ||
        ctx.changeSet.structuralChanged ||
        ctx.changeSet.boundsChanged ||
        ctx.changeSet.documentReplaced;
    final nextVisualRevision =
        _store.visualRevision + (shouldBumpVisual ? 1 : 0);

    _spatialIndexSlice.writeHandleCommit(
      changeSet: ctx.changeSet,
      controllerEpoch: nextEpoch,
      boundsRevision: nextBoundsRevision,
    );
    commitPhases = <String>[...commitPhases, 'spatial_index'];

    final nextCommitRevision = _store.commitRevision + 1;
    _signalsSlice.writeFlushBuffered(commitRevision: nextCommitRevision);
    commitPhases = <String>[...commitPhases, 'signals'];

    if (ctx.changeSet.txnHasAnyChange) {
      _repaintSlice.writeMarkNeedsRepaint();
    }

    _store.sceneDoc = ctx.workingScene;
    _store.selectedNodeIds = ctx.workingSelection;
    _store.allNodeIds = txnCollectNodeIds(ctx.workingScene);
    _store.nodeIdSeed = ctx.nodeIdSeed;

    _store.controllerEpoch = nextEpoch;
    _store.structuralRevision = nextStructuralRevision;
    _store.boundsRevision = nextBoundsRevision;
    _store.visualRevision = nextVisualRevision;
    _store.commitRevision = nextCommitRevision;

    _repaintSlice.writeFlushNotify(notifyListeners);
    commitPhases = <String>[...commitPhases, 'repaint'];

    _debugLastCommitPhases = commitPhases;
    _debugLastChangeSet = ctx.changeSet.txnClone();
  }

  @override
  void dispose() {
    _signalsSlice.dispose();
    super.dispose();
  }
}
