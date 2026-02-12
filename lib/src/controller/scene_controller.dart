import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/nodes.dart' show SceneNode;
import '../core/scene_spatial_index.dart';
import '../input/slices/commands/scene_commands.dart';
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
import '../public/scene_render_state.dart';
import '../public/scene_write_txn.dart';
import '../public/snapshot.dart';
import 'change_set.dart';
import 'scene_invariants.dart';
import 'scene_writer.dart';
import 'store.dart';
import 'txn_context.dart';

class SceneControllerV2 extends ChangeNotifier implements SceneRenderState {
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
  bool _notifyScheduled = false;
  bool _notifyPending = false;
  bool _isDisposed = false;
  List<String> _debugLastCommitPhases = const <String>[];
  ChangeSet _debugLastChangeSet = ChangeSet();

  late final V2SceneCommandsSlice commands = V2SceneCommandsSlice(write);
  late final V2MoveSlice move = V2MoveSlice(write);
  late final V2DrawSlice draw = V2DrawSlice(write);

  @override
  SceneSnapshot get snapshot => txnSceneToSnapshot(_store.sceneDoc);

  @override
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

  int get debugCommitRevision => _store.commitRevision;

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

    // v2 commits may replace sceneDoc identity on structural/geometry writes.
    // For stale candidates after such commits, id/type still allows safe
    // fallback resolution when coordinates remain valid.
    if (node.id != candidate.node.id || node.type != candidate.node.type) {
      return null;
    }
    return node;
  }

  T write<T>(T Function(SceneWriteTxn txn) fn) {
    if (_writeInProgress) {
      throw StateError('Nested write(...) calls are not allowed.');
    }

    _writeInProgress = true;
    final ctx = TxnContext(
      baseScene: _store.sceneDoc,
      workingSelection: Set<NodeId>.from(_store.selectedNodeIds),
      workingNodeIds: Set<NodeId>.from(_store.allNodeIds),
      nodeIdSeed: _store.nodeIdSeed,
    );

    late final T result;
    var commitResult = const _TxnWriteCommitResult(
      committedSignals: <V2CommittedSignal>[],
      needsNotify: false,
    );

    try {
      final writer = SceneWriter(
        ctx,
        txnSignalSink: _signalsSlice.writeBufferSignal,
      );
      result = fn(writer);
      commitResult = _txnWriteCommit(ctx);
    } catch (_) {
      _signalsSlice.writeDiscardBuffered();
      _repaintSlice.writeDiscardPending();
      rethrow;
    } finally {
      _writeInProgress = false;
    }

    _signalsSlice.emitCommitted(commitResult.committedSignals);
    if (commitResult.needsNotify) {
      _scheduleNotify();
    }
    return result;
  }

  void writeReplaceScene(SceneSnapshot snapshot) {
    write<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }

  void requestRepaint() {
    _repaintSlice.writeMarkNeedsRepaint();
    if (_writeInProgress) {
      return;
    }
    if (_repaintSlice.writeTakeNeedsNotify()) {
      _scheduleNotify();
    }
  }

  _TxnWriteCommitResult _txnWriteCommit(TxnContext ctx) {
    var commitPhases = const <String>[];

    final shouldNormalizeSelection =
        ctx.changeSet.selectionChanged ||
        ctx.changeSet.structuralChanged ||
        ctx.changeSet.documentReplaced;
    if (shouldNormalizeSelection) {
      final selectionResult = _selectionSlice.writeNormalizeSelection(
        rawSelection: ctx.workingSelection,
        scene: ctx.workingScene,
      );
      commitPhases = <String>[...commitPhases, 'selection'];
      if (selectionResult.normalizedChanged) {
        ctx.changeSet.txnMarkSelectionChanged();
      }
      ctx.workingSelection = selectionResult.normalized;
    }

    final shouldNormalizeGrid =
        ctx.changeSet.gridChanged || ctx.changeSet.documentReplaced;
    if (shouldNormalizeGrid) {
      final gridChanged = _gridSlice.writeNormalizeGrid(
        scene: ctx.workingScene,
      );
      commitPhases = <String>[...commitPhases, 'grid'];
      if (gridChanged) {
        ctx.changeSet.txnMarkGridChanged();
      }
    }

    final hasStateChanges = ctx.changeSet.txnHasAnyChange;
    final hasSignals = _signalsSlice.writeHasBufferedSignals;
    final hasRepaint = _repaintSlice.needsNotify;
    if (!hasStateChanges && !hasSignals && !hasRepaint) {
      _debugLastCommitPhases = commitPhases;
      _debugLastChangeSet = ctx.changeSet.txnClone();
      return const _TxnWriteCommitResult(
        committedSignals: <V2CommittedSignal>[],
        needsNotify: false,
      );
    }

    if (!hasStateChanges) {
      var committedSignals = const <V2CommittedSignal>[];
      if (hasSignals) {
        final nextCommitRevision = _store.commitRevision + 1;
        committedSignals = _signalsSlice.writeTakeCommitted(
          commitRevision: nextCommitRevision,
        );
        commitPhases = <String>[...commitPhases, 'signals'];
        _store.commitRevision = nextCommitRevision;
        _debugAssertStoreInvariants();
      }

      final needsNotify = _repaintSlice.writeTakeNeedsNotify();
      if (needsNotify) {
        commitPhases = <String>[...commitPhases, 'repaint'];
      }
      _debugLastCommitPhases = commitPhases;
      _debugLastChangeSet = ctx.changeSet.txnClone();
      return _TxnWriteCommitResult(
        committedSignals: committedSignals,
        needsNotify: needsNotify,
      );
    }

    final nextEpoch =
        _store.controllerEpoch + (ctx.changeSet.documentReplaced ? 1 : 0);
    final nextStructuralRevision =
        _store.structuralRevision + (ctx.changeSet.structuralChanged ? 1 : 0);
    final nextBoundsRevision =
        _store.boundsRevision + (ctx.changeSet.boundsChanged ? 1 : 0);
    // In state-change branch any committed mutation must bump visual revision.
    final nextVisualRevision = _store.visualRevision + 1;

    _spatialIndexSlice.writeHandleCommit(
      changeSet: ctx.changeSet,
      controllerEpoch: nextEpoch,
      boundsRevision: nextBoundsRevision,
    );
    commitPhases = <String>[...commitPhases, 'spatial_index'];

    final nextCommitRevision = _store.commitRevision + 1;
    final committedSignals = _signalsSlice.writeTakeCommitted(
      commitRevision: nextCommitRevision,
    );
    commitPhases = <String>[...commitPhases, 'signals'];

    final committedScene = ctx.txnSceneForCommit();
    final committedSelection = Set<NodeId>.from(ctx.workingSelection);
    final committedNodeIds = txnCollectNodeIds(committedScene);
    final committedNodeIdSeed = txnInitialNodeIdSeed(committedScene);

    _store.sceneDoc = committedScene;
    _store.selectedNodeIds = committedSelection;
    _store.allNodeIds = committedNodeIds;
    _store.nodeIdSeed = committedNodeIdSeed;
    _store.controllerEpoch = nextEpoch;
    _store.structuralRevision = nextStructuralRevision;
    _store.boundsRevision = nextBoundsRevision;
    _store.visualRevision = nextVisualRevision;
    _store.commitRevision = nextCommitRevision;
    _debugAssertStoreInvariants();

    _repaintSlice.writeMarkNeedsRepaint();
    final needsNotify = _repaintSlice.writeTakeNeedsNotify();
    commitPhases = <String>[...commitPhases, 'repaint'];

    _debugLastCommitPhases = commitPhases;
    _debugLastChangeSet = ctx.changeSet.txnClone();
    return _TxnWriteCommitResult(
      committedSignals: committedSignals,
      needsNotify: needsNotify,
    );
  }

  void _scheduleNotify() {
    if (_isDisposed) {
      return;
    }
    _notifyPending = true;
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;

    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_isDisposed || !_notifyPending) {
        return;
      }
      _notifyPending = false;
      notifyListeners();
    });
  }

  void _debugAssertStoreInvariants() {
    debugAssertTxnStoreInvariants(
      scene: _store.sceneDoc,
      selectedNodeIds: _store.selectedNodeIds,
      allNodeIds: _store.allNodeIds,
      nodeIdSeed: _store.nodeIdSeed,
      commitRevision: _store.commitRevision,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notifyPending = false;
    _notifyScheduled = false;
    _signalsSlice.dispose();
    super.dispose();
  }
}

class _TxnWriteCommitResult {
  const _TxnWriteCommitResult({
    required this.committedSignals,
    required this.needsNotify,
  });

  final List<V2CommittedSignal> committedSignals;
  final bool needsNotify;
}
