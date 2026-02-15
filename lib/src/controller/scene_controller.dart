import 'dart:async';
import 'dart:collection';
import 'dart:ui' hide Scene;

import 'package:flutter/foundation.dart';

import '../core/nodes.dart' show SceneNode;
import '../core/scene.dart' show Scene;
import '../core/scene_spatial_index.dart';
import 'commands/draw_commands.dart';
import 'commands/move_commands.dart';
import 'commands/scene_commands.dart';
import 'internal/grid_normalizer.dart';
import 'internal/repaint_flag.dart';
import 'internal/selection_normalizer.dart';
import 'internal/signal_event.dart';
import 'internal/signals_buffer.dart';
import 'internal/spatial_index_cache.dart';
import '../model/document.dart';
import '../public/scene_render_state.dart';
import '../public/scene_write_txn.dart';
import '../public/snapshot.dart';
import 'change_set.dart';
import 'scene_invariants.dart';
import 'scene_writer.dart';
import 'store.dart';
import 'txn_context.dart';

class SceneControllerCore extends ChangeNotifier implements SceneRenderState {
  SceneControllerCore({SceneSnapshot? initialSnapshot})
    : _store = SceneStore(
        sceneDoc: txnSceneFromSnapshot(initialSnapshot ?? SceneSnapshot()),
      ) {
    _selectedNodeIdsView = UnmodifiableSetView<NodeId>(_store.selectedNodeIds);
  }

  final SceneStore _store;

  final SelectionNormalizer _selectionNormalizer = SelectionNormalizer();
  final GridNormalizer _gridNormalizer = GridNormalizer();
  final SpatialIndexCache _spatialIndexCache = SpatialIndexCache();
  final SignalsBuffer _signalsBuffer = SignalsBuffer();
  final RepaintFlag _repaintFlag = RepaintFlag();

  bool _writeInProgress = false;
  bool _notifyScheduled = false;
  bool _notifyPending = false;
  bool _isDisposed = false;
  Scene? _cachedSnapshotScene;
  SceneSnapshot? _cachedSnapshot;
  late UnmodifiableSetView<NodeId> _selectedNodeIdsView;
  List<String> _debugLastCommitPhases = const <String>[];
  ChangeSet _debugLastChangeSet = ChangeSet();
  int _debugLastSceneShallowClones = 0;
  int _debugLastLayerShallowClones = 0;
  int _debugLastNodeClones = 0;
  int _debugLastNodeIdSetMaterializations = 0;
  int _debugLastNodeLocatorMaterializations = 0;
  @visibleForTesting
  void Function()? debugBeforeInvariantPrecheckHook;
  @visibleForTesting
  void Function()? debugBeforeSpatialPrepareCommitHook;

  late final SceneCommands commands = SceneCommands(write);
  late final MoveCommands move = MoveCommands(write);
  late final DrawCommands draw = DrawCommands(write);

  @override
  SceneSnapshot get snapshot {
    final sceneDoc = _store.sceneDoc;
    final cachedSnapshot = _cachedSnapshot;
    if (cachedSnapshot != null && identical(sceneDoc, _cachedSnapshotScene)) {
      return cachedSnapshot;
    }

    // Safe because committed scene identity changes on first mutating write.
    // Non-mutating commits keep identity and can reuse immutable snapshot.
    final rebuiltSnapshot = txnSceneToSnapshot(sceneDoc);
    _cachedSnapshotScene = sceneDoc;
    _cachedSnapshot = rebuiltSnapshot;
    return rebuiltSnapshot;
  }

  @override
  Set<NodeId> get selectedNodeIds => _selectedNodeIdsView;

  int get controllerEpoch => _store.controllerEpoch;
  int get structuralRevision => _store.structuralRevision;
  int get boundsRevision => _store.boundsRevision;
  int get visualRevision => _store.visualRevision;

  Stream<CommittedSignal> get signals => _signalsBuffer.signals;

  @visibleForTesting
  List<String> get debugLastCommitPhases => _debugLastCommitPhases;

  @visibleForTesting
  ChangeSet get debugLastChangeSet => _debugLastChangeSet.txnClone();

  @visibleForTesting
  int get debugSpatialIndexBuildCount => _spatialIndexCache.debugBuildCount;

  @visibleForTesting
  int get debugSpatialIndexIncrementalApplyCount =>
      _spatialIndexCache.debugIncrementalApplyCount;

  @visibleForTesting
  int get debugSceneShallowClones => _debugLastSceneShallowClones;

  @visibleForTesting
  int get debugLayerShallowClones => _debugLastLayerShallowClones;

  @visibleForTesting
  int get debugNodeClones => _debugLastNodeClones;

  @visibleForTesting
  int get debugNodeIdSetMaterializations => _debugLastNodeIdSetMaterializations;

  @visibleForTesting
  int get debugNodeLocatorMaterializations =>
      _debugLastNodeLocatorMaterializations;

  int get debugCommitRevision => _store.commitRevision;

  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) {
    return _spatialIndexCache.writeQueryCandidates(
      scene: _store.sceneDoc,
      nodeLocator: _store.nodeLocator,
      worldBounds: worldBounds,
      controllerEpoch: _store.controllerEpoch,
    );
  }

  SceneNode? resolveSpatialCandidateNode(SceneSpatialCandidate candidate) {
    final layerIndex = candidate.layerIndex;
    if (layerIndex < 0 || layerIndex >= _store.sceneDoc.layers.length) {
      return null;
    }

    final layer = _store.sceneDoc.layers[layerIndex];
    final nodeIndex = candidate.nodeIndex;
    if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
      return null;
    }

    final node = layer.nodes[nodeIndex];
    if (identical(node, candidate.node)) {
      return node;
    }

    // Commits may replace sceneDoc identity on structural/geometry writes.
    // For stale candidates after such commits, id/type still allows safe
    // fallback resolution when coordinates remain valid.
    if (node.id != candidate.node.id || node.type != candidate.node.type) {
      return null;
    }
    return node;
  }

  T write<T>(T Function(SceneWriteTxn txn) fn) {
    _throwIfDisposed();
    if (_writeInProgress) {
      throw StateError('Nested write(...) calls are not allowed.');
    }

    _writeInProgress = true;
    final ctx = TxnContext(
      baseScene: _store.sceneDoc,
      workingSelection: HashSet<NodeId>.of(_store.selectedNodeIds),
      baseAllNodeIds: _store.allNodeIds,
      baseNodeLocator: _store.nodeLocator,
      nodeIdSeed: _store.nodeIdSeed,
      nextInstanceRevision: _store.nextInstanceRevision,
    );

    late final T result;
    var commitResult = const _TxnWriteCommitResult(
      committedSignals: <CommittedSignal>[],
      needsNotify: false,
    );

    try {
      final writer = SceneWriter(
        ctx,
        txnSignalSink: _signalsBuffer.writeBufferSignal,
      );
      result = fn(writer);
      commitResult = _txnWriteCommit(ctx);
    } catch (_) {
      _signalsBuffer.writeDiscardBuffered();
      _repaintFlag.writeDiscardPending();
      rethrow;
    } finally {
      ctx.txnClose();
      _writeInProgress = false;
    }

    _signalsBuffer.emitCommitted(commitResult.committedSignals);
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
    _throwIfDisposed();
    _repaintFlag.writeMarkNeedsRepaint();
    if (_writeInProgress) {
      return;
    }
    if (_repaintFlag.writeTakeNeedsNotify()) {
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
      final selectionResult = _selectionNormalizer.writeNormalizeSelection(
        rawSelection: ctx.workingSelection,
        scene: ctx.workingScene,
      );
      commitPhases = <String>[...commitPhases, 'selection'];
      if (selectionResult.normalizedChanged) {
        ctx.changeSet.txnMarkSelectionChanged();
      }
      if (!identical(selectionResult.normalized, ctx.workingSelection)) {
        ctx.workingSelection
          ..clear()
          ..addAll(selectionResult.normalized);
      }
    }

    final shouldNormalizeGrid =
        ctx.changeSet.gridChanged || ctx.changeSet.documentReplaced;
    if (shouldNormalizeGrid) {
      final gridChanged = _gridNormalizer.writeNormalizeGrid(
        scene: ctx.workingScene,
      );
      commitPhases = <String>[...commitPhases, 'grid'];
      if (gridChanged) {
        ctx.changeSet.txnMarkGridChanged();
      }
    }

    final hasStateChanges = ctx.changeSet.txnHasAnyChange;
    final hasSignals = _signalsBuffer.writeHasBufferedSignals;
    final hasRepaint = _repaintFlag.needsNotify;
    if (!hasStateChanges && !hasSignals && !hasRepaint) {
      _debugLastCommitPhases = commitPhases;
      _debugLastChangeSet = ctx.changeSet.txnClone();
      _debugCaptureTxnCloneStats(ctx);
      return const _TxnWriteCommitResult(
        committedSignals: <CommittedSignal>[],
        needsNotify: false,
      );
    }

    if (!hasStateChanges) {
      var committedSignals = const <CommittedSignal>[];
      if (hasSignals) {
        final nextCommitRevision = _store.commitRevision + 1;
        _debugAssertStoreInvariantsCandidate(
          scene: _store.sceneDoc,
          selectedNodeIds: _store.selectedNodeIds,
          allNodeIds: _store.allNodeIds,
          nodeLocator: _store.nodeLocator,
          nodeIdSeed: _store.nodeIdSeed,
          nextInstanceRevision: _store.nextInstanceRevision,
          commitRevision: nextCommitRevision,
        );
        committedSignals = _signalsBuffer.writeTakeCommitted(
          commitRevision: nextCommitRevision,
        );
        commitPhases = <String>[...commitPhases, 'signals'];
        _store.commitRevision = nextCommitRevision;
      }

      final needsNotify = _repaintFlag.writeTakeNeedsNotify();
      if (needsNotify) {
        commitPhases = <String>[...commitPhases, 'repaint'];
      }
      _debugLastCommitPhases = commitPhases;
      _debugLastChangeSet = ctx.changeSet.txnClone();
      _debugCaptureTxnCloneStats(ctx);
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

    final nextCommitRevision = _store.commitRevision + 1;
    final committedScene = ctx.txnSceneForCommit();
    final committedSelection = ctx.changeSet.selectionChanged
        ? HashSet<NodeId>.of(ctx.workingSelection)
        : _store.selectedNodeIds;
    final committedNodeIds = ctx.txnAllNodeIdsForCommit(
      structuralChanged: ctx.changeSet.structuralChanged,
    );
    final committedNodeLocator = ctx.txnNodeLocatorForCommit(
      structuralChanged: ctx.changeSet.structuralChanged,
    );
    final committedNodeIdSeed = ctx.nodeIdSeed;
    final committedNextInstanceRevision = ctx.nextInstanceRevision;
    _debugAssertStoreInvariantsCandidate(
      scene: committedScene,
      selectedNodeIds: committedSelection,
      allNodeIds: committedNodeIds,
      nodeLocator: committedNodeLocator,
      nodeIdSeed: committedNodeIdSeed,
      nextInstanceRevision: committedNextInstanceRevision,
      commitRevision: nextCommitRevision,
    );

    debugBeforeSpatialPrepareCommitHook?.call();
    final preparedSpatialCommit = _spatialIndexCache.writePrepareCommit(
      scene: committedScene,
      nodeLocator: committedNodeLocator,
      changeSet: ctx.changeSet,
      controllerEpoch: nextEpoch,
    );

    final committedSignals = _signalsBuffer.writeTakeCommitted(
      commitRevision: nextCommitRevision,
    );

    _applyCommittedStore(
      committedScene: committedScene,
      committedSelection: committedSelection,
      committedNodeIds: committedNodeIds,
      committedNodeLocator: committedNodeLocator,
      committedNodeIdSeed: committedNodeIdSeed,
      committedNextInstanceRevision: committedNextInstanceRevision,
      nextEpoch: nextEpoch,
      nextStructuralRevision: nextStructuralRevision,
      nextBoundsRevision: nextBoundsRevision,
      nextVisualRevision: nextVisualRevision,
      nextCommitRevision: nextCommitRevision,
    );
    _spatialIndexCache.writeApplyPreparedCommit(preparedSpatialCommit);
    commitPhases = <String>[...commitPhases, 'spatial_index'];
    commitPhases = <String>[...commitPhases, 'signals'];

    _repaintFlag.writeMarkNeedsRepaint();
    final needsNotify = _repaintFlag.writeTakeNeedsNotify();
    commitPhases = <String>[...commitPhases, 'repaint'];

    _debugLastCommitPhases = commitPhases;
    _debugLastChangeSet = ctx.changeSet.txnClone();
    _debugCaptureTxnCloneStats(ctx);
    return _TxnWriteCommitResult(
      committedSignals: committedSignals,
      needsNotify: needsNotify,
    );
  }

  void _applyCommittedStore({
    required Scene committedScene,
    required Set<NodeId> committedSelection,
    required Set<NodeId> committedNodeIds,
    required Map<NodeId, NodeLocatorEntry> committedNodeLocator,
    required int committedNodeIdSeed,
    required int committedNextInstanceRevision,
    required int nextEpoch,
    required int nextStructuralRevision,
    required int nextBoundsRevision,
    required int nextVisualRevision,
    required int nextCommitRevision,
  }) {
    _store.sceneDoc = committedScene;
    if (!identical(_store.selectedNodeIds, committedSelection)) {
      _store.selectedNodeIds = committedSelection;
      _selectedNodeIdsView = UnmodifiableSetView<NodeId>(committedSelection);
    }
    _store.allNodeIds = committedNodeIds;
    _store.nodeLocator = committedNodeLocator;
    _store.nodeIdSeed = committedNodeIdSeed;
    _store.nextInstanceRevision = committedNextInstanceRevision;
    _store.controllerEpoch = nextEpoch;
    _store.structuralRevision = nextStructuralRevision;
    _store.boundsRevision = nextBoundsRevision;
    _store.visualRevision = nextVisualRevision;
    _store.commitRevision = nextCommitRevision;
  }

  void _debugCaptureTxnCloneStats(TxnContext ctx) {
    _debugLastSceneShallowClones = ctx.debugSceneShallowClones;
    _debugLastLayerShallowClones = ctx.debugLayerShallowClones;
    _debugLastNodeClones = ctx.debugNodeClones;
    _debugLastNodeIdSetMaterializations = ctx.debugNodeIdSetMaterializations;
    _debugLastNodeLocatorMaterializations =
        ctx.debugNodeLocatorMaterializations;
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

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('Controller is disposed.');
    }
  }

  void _debugAssertStoreInvariantsCandidate({
    required Scene scene,
    required Set<NodeId> selectedNodeIds,
    required Set<NodeId> allNodeIds,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required int nodeIdSeed,
    required int nextInstanceRevision,
    required int commitRevision,
  }) {
    assert(() {
      debugBeforeInvariantPrecheckHook?.call();
      return true;
    }());
    debugAssertTxnStoreInvariants(
      scene: scene,
      selectedNodeIds: selectedNodeIds,
      allNodeIds: allNodeIds,
      nodeLocator: nodeLocator,
      nodeIdSeed: nodeIdSeed,
      nextInstanceRevision: nextInstanceRevision,
      commitRevision: commitRevision,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notifyPending = false;
    _notifyScheduled = false;
    _signalsBuffer.dispose();
    super.dispose();
  }
}

class _TxnWriteCommitResult {
  const _TxnWriteCommitResult({
    required this.committedSignals,
    required this.needsNotify,
  });

  final List<CommittedSignal> committedSignals;
  final bool needsNotify;
}
