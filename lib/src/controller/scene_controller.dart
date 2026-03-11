import 'dart:async';
import 'dart:collection';
import 'dart:ui' hide Scene;

import 'package:flutter/foundation.dart';

import '../core/nodes.dart' show SceneNode;
import '../core/id_generator.dart' show IdGeneratorState;
import '../core/revision_policy.dart';
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
import '../contract/scene_render_state.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import 'change_set.dart';
import 'mutation_executor.dart';
import 'scene_invariants.dart';
import 'scene_writer.dart';
import 'store.dart';
import 'txn_context.dart';

class SceneControllerCore extends ChangeNotifier implements SceneRenderState {
  SceneControllerCore({
    SceneSnapshot? initialSnapshot,
    this.textFontFamilyByDefault,
  }) : _store = SceneStore(
         sceneDoc: txnSceneFromSnapshot(initialSnapshot ?? SceneSnapshot()),
       ) {
    _selectedNodeIdsView = UnmodifiableSetView<NodeId>(_store.selectedNodeIds);
    _mutationExecutor = MutationExecutor(
      textFontFamilyByDefault: textFontFamilyByDefault,
    );
  }

  final SceneStore _store;
  final String? textFontFamilyByDefault;
  late final MutationExecutor _mutationExecutor;

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
  @visibleForTesting
  void Function()? debugBeforeTxnContextCreateHook;

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

  @visibleForTesting
  int get debugCommitRevision => _store.commitRevision;

  @visibleForTesting
  IdGeneratorState get debugIdGeneratorState => _store.idGeneratorState.copy();

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
    TxnContext? ctx;

    late final T result;
    var commitResult = const _TxnWriteCommitResult(
      committedSignals: <CommittedSignal>[],
      needsNotify: false,
    );

    try {
      debugBeforeTxnContextCreateHook?.call();
      final createdCtx = TxnContext(
        baseScene: _store.sceneDoc,
        workingSelection: HashSet<NodeId>.of(_store.selectedNodeIds),
        baseAllNodeIds: _store.allNodeIds,
        baseNodeLocator: _store.nodeLocator,
        idGeneratorState: _store.idGeneratorState,
        revisionState: _store.revisionState,
      );
      ctx = createdCtx;
      final writer = SceneWriter(
        createdCtx,
        mutationExecutor: _mutationExecutor,
        txnSignalSink: _signalsBuffer.writeBufferSignal,
      );
      result = fn(writer);
      if (result is Future) {
        throw StateError(
          'Async write callbacks are not supported. '
          'Return synchronously from write(...).',
        );
      }
      commitResult = _txnWriteCommit(createdCtx);
    } catch (_) {
      _signalsBuffer.writeDiscardBuffered();
      _repaintFlag.writeDiscardPending();
      rethrow;
    } finally {
      ctx?.txnClose();
      _writeInProgress = false;
    }

    _dispatchPostCommitEffects(commitResult);
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
    final normalizedPhases = _normalizeCommitInputs(ctx);
    final commitPlan = _buildControllerCommitPlan(
      ctx,
      initialPhases: normalizedPhases,
    );
    final execution = _executeControllerCommitPlan(commitPlan);
    _debugLastCommitPhases = execution.commitPhases;
    _debugLastChangeSet = commitPlan.changeSet;
    _debugCaptureTxnCloneStats(ctx);
    return execution.commitResult;
  }

  List<String> _normalizeCommitInputs(TxnContext ctx) {
    var commitPhases = const <String>[];

    // Selection commands normalize input at writer boundary. Commit-time
    // normalization remains a safety net for structural/document changes and
    // for non-command selection-affecting mutations (for example node patches).
    final shouldNormalizeSelection =
        ctx.changeSet.selectionChanged ||
        ctx.changeSet.structuralChanged ||
        ctx.changeSet.documentReplaced;
    if (shouldNormalizeSelection) {
      final selectionResult = _selectionNormalizer.writeNormalizeSelection(
        rawSelection: ctx.workingSelection,
        scene: ctx.workingScene,
        nodeLocator: ctx.txnNodeLocatorView(),
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

    return commitPhases;
  }

  _ControllerCommitPlan _buildControllerCommitPlan(
    TxnContext ctx, {
    required List<String> initialPhases,
  }) {
    final preparedCommit = _mutationExecutor.prepareCommitResult(ctx);
    final changeSet = preparedCommit.changeSet;
    final commitCandidate = preparedCommit.commitCandidate;
    final hasSignals = _signalsBuffer.writeHasBufferedSignals;
    final hasRepaint = _repaintFlag.needsNotify;

    if (commitCandidate == null && !hasSignals && !hasRepaint) {
      return _ControllerCommitPlan.noEffects(
        changeSet: changeSet,
        initialPhases: initialPhases,
      );
    }

    if (commitCandidate == null) {
      return _ControllerCommitPlan.effectsOnly(
        changeSet: changeSet,
        initialPhases: initialPhases,
        nextCommitRevision: hasSignals ? _store.commitRevision + 1 : null,
        shouldCommitSignals: hasSignals,
        shouldNotify: hasRepaint,
      );
    }

    final committedSelection = changeSet.selectionChanged
        ? commitCandidate.selection
        : _store.selectedNodeIds;
    final committedRevisionState = resolvedCommittedRevisionAllocatorState(
      commitCandidate.revisionState,
    );
    return _ControllerCommitPlan.stateCommit(
      changeSet: changeSet,
      initialPhases: initialPhases,
      commitCandidate: commitCandidate,
      committedSelection: committedSelection,
      committedRevisionState: committedRevisionState,
      nextEpoch: resolveNextControllerEpoch(
        currentEpoch: _store.controllerEpoch,
        documentReplaced: changeSet.documentReplaced,
        revisionState: commitCandidate.revisionState,
      ),
      nextStructuralRevision:
          _store.structuralRevision + (changeSet.structuralChanged ? 1 : 0),
      nextBoundsRevision:
          _store.boundsRevision + (changeSet.boundsChanged ? 1 : 0),
      nextVisualRevision: _store.visualRevision + 1,
      nextCommitRevision: _store.commitRevision + 1,
      shouldMarkRepaint: true,
    );
  }

  _ControllerCommitExecution _executeControllerCommitPlan(
    _ControllerCommitPlan plan,
  ) {
    return switch (plan.branchKind) {
      _ControllerCommitBranchKind.noEffects => _ControllerCommitExecution(
        commitPhases: plan.initialPhases,
        commitResult: const _TxnWriteCommitResult(
          committedSignals: <CommittedSignal>[],
          needsNotify: false,
        ),
      ),
      _ControllerCommitBranchKind.effectsOnly => _executeEffectsOnlyCommitPlan(
        plan,
        nextCommitRevision: plan.nextCommitRevision,
      ),
      _ControllerCommitBranchKind.stateCommit => _executeStateCommitPlan(
        plan,
        committed: plan.commitCandidate as MutationCommitCandidate,
        committedSelection: plan.committedSelection as Set<NodeId>,
        committedRevisionState:
            plan.committedRevisionState as RevisionAllocatorState,
        nextEpoch: plan.nextEpoch as int,
        nextStructuralRevision: plan.nextStructuralRevision as int,
        nextBoundsRevision: plan.nextBoundsRevision as int,
        nextVisualRevision: plan.nextVisualRevision as int,
        nextCommitRevision: plan.nextCommitRevision as int,
      ),
    };
  }

  _ControllerCommitExecution _executeEffectsOnlyCommitPlan(
    _ControllerCommitPlan plan, {
    required int? nextCommitRevision,
  }) {
    var commitPhases = plan.initialPhases;
    var committedSignals = const <CommittedSignal>[];

    if (plan.shouldCommitSignals) {
      final resolvedNextCommitRevision = nextCommitRevision as int;
      _assertStoreInvariantsCandidate(
        scene: _store.sceneDoc,
        selectedNodeIds: _store.selectedNodeIds,
        allNodeIds: _store.allNodeIds,
        nodeLocator: _store.nodeLocator,
        idGeneratorState: _store.idGeneratorState,
        controllerEpoch: _store.controllerEpoch,
        revisionState: _store.revisionState,
        commitRevision: resolvedNextCommitRevision,
        previousCommitRevision: _store.commitRevision,
      );
      committedSignals = _signalsBuffer.writeTakeCommitted(
        commitRevision: resolvedNextCommitRevision,
      );
      _store.commitRevision = resolvedNextCommitRevision;
      commitPhases = <String>[...commitPhases, 'signals'];
    }

    final needsNotify = plan.shouldNotify
        ? _repaintFlag.writeTakeNeedsNotify()
        : false;
    if (needsNotify) {
      commitPhases = <String>[...commitPhases, 'repaint'];
    }

    return _ControllerCommitExecution(
      commitPhases: commitPhases,
      commitResult: _TxnWriteCommitResult(
        committedSignals: committedSignals,
        needsNotify: needsNotify,
      ),
    );
  }

  _ControllerCommitExecution _executeStateCommitPlan(
    _ControllerCommitPlan plan, {
    required MutationCommitCandidate committed,
    required Set<NodeId> committedSelection,
    required RevisionAllocatorState committedRevisionState,
    required int nextEpoch,
    required int nextStructuralRevision,
    required int nextBoundsRevision,
    required int nextVisualRevision,
    required int nextCommitRevision,
  }) {
    _assertStoreInvariantsCandidate(
      scene: committed.scene,
      selectedNodeIds: committedSelection,
      allNodeIds: committed.allNodeIds,
      nodeLocator: committed.nodeLocator,
      idGeneratorState: committed.idGeneratorState,
      controllerEpoch: nextEpoch,
      revisionState: committedRevisionState,
      commitRevision: nextCommitRevision,
      previousCommitRevision: _store.commitRevision,
    );

    debugBeforeSpatialPrepareCommitHook?.call();
    final preparedSpatialCommit = _spatialIndexCache.writePrepareCommit(
      scene: committed.scene,
      nodeLocator: committed.nodeLocator,
      changeSet: plan.changeSet,
      controllerEpoch: nextEpoch,
    );

    final committedSignals = _signalsBuffer.writeTakeCommitted(
      commitRevision: nextCommitRevision,
    );

    _applyCommittedStore(
      committedScene: committed.scene,
      committedSelection: committedSelection,
      committedNodeIds: committed.allNodeIds,
      committedNodeLocator: committed.nodeLocator,
      committedIdGeneratorState: committed.idGeneratorState,
      committedRevisionState: committedRevisionState,
      nextEpoch: nextEpoch,
      nextStructuralRevision: nextStructuralRevision,
      nextBoundsRevision: nextBoundsRevision,
      nextVisualRevision: nextVisualRevision,
      nextCommitRevision: nextCommitRevision,
    );
    _spatialIndexCache.writeApplyPreparedCommit(preparedSpatialCommit);

    var commitPhases = <String>[
      ...plan.initialPhases,
      'spatial_index',
      'signals',
    ];
    if (plan.shouldMarkRepaint) {
      _repaintFlag.writeMarkNeedsRepaint();
    }
    final needsNotify = _repaintFlag.writeTakeNeedsNotify();
    if (needsNotify) {
      commitPhases = <String>[...commitPhases, 'repaint'];
    }

    return _ControllerCommitExecution(
      commitPhases: commitPhases,
      commitResult: _TxnWriteCommitResult(
        committedSignals: committedSignals,
        needsNotify: needsNotify,
      ),
    );
  }

  void _applyCommittedStore({
    required Scene committedScene,
    required Set<NodeId> committedSelection,
    required Set<NodeId> committedNodeIds,
    required Map<NodeId, NodeLocatorEntry> committedNodeLocator,
    required IdGeneratorState committedIdGeneratorState,
    required RevisionAllocatorState committedRevisionState,
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
    _store.idGeneratorState = committedIdGeneratorState;
    _store.revisionState = committedRevisionState;
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

  void _dispatchPostCommitEffects(_TxnWriteCommitResult commitResult) {
    final committedSignals = commitResult.committedSignals;
    final needsNotify = commitResult.needsNotify;
    if (committedSignals.isNotEmpty) {
      _signalsBuffer.emitCommitted(committedSignals);
    }
    if (!needsNotify) {
      return;
    }
    if (committedSignals.isEmpty) {
      _scheduleNotify();
      return;
    }

    // Keep deterministic post-commit order for same-commit observers:
    // signals are enqueued first, notify is scheduled after a microtask hop.
    scheduleMicrotask(() {
      _scheduleNotify();
    });
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

  void _assertStoreInvariantsCandidate({
    required Scene scene,
    required Set<NodeId> selectedNodeIds,
    required Set<NodeId> allNodeIds,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required IdGeneratorState idGeneratorState,
    required int controllerEpoch,
    required RevisionAllocatorState revisionState,
    required int commitRevision,
    required int previousCommitRevision,
  }) {
    assertCriticalTxnStoreInvariants(
      scene: scene,
      commitRevision: commitRevision,
      previousCommitRevision: previousCommitRevision,
    );
    if (!kDebugMode && !kProfileMode) {
      return;
    }
    assert(() {
      debugBeforeInvariantPrecheckHook?.call();
      return true;
    }());
    debugAssertTxnStoreInvariants(
      scene: scene,
      selectedNodeIds: selectedNodeIds,
      allNodeIds: allNodeIds,
      nodeLocator: nodeLocator,
      idGeneratorState: idGeneratorState,
      controllerEpoch: controllerEpoch,
      revisionState: revisionState,
      commitRevision: commitRevision,
    );
  }

  @override
  void dispose() {
    if (_writeInProgress) {
      throw StateError('dispose() is not allowed during active write(...).');
    }
    if (_isDisposed) {
      return;
    }
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

class _ControllerCommitExecution {
  const _ControllerCommitExecution({
    required this.commitPhases,
    required this.commitResult,
  });

  final List<String> commitPhases;
  final _TxnWriteCommitResult commitResult;
}

enum _ControllerCommitBranchKind { noEffects, effectsOnly, stateCommit }

class _ControllerCommitPlan {
  const _ControllerCommitPlan._({
    required this.branchKind,
    required this.changeSet,
    required this.initialPhases,
    required this.commitCandidate,
    required this.committedSelection,
    required this.committedRevisionState,
    required this.nextEpoch,
    required this.nextStructuralRevision,
    required this.nextBoundsRevision,
    required this.nextVisualRevision,
    required this.nextCommitRevision,
    required this.shouldCommitSignals,
    required this.shouldNotify,
    required this.shouldMarkRepaint,
  });

  const _ControllerCommitPlan.noEffects({
    required ChangeSet changeSet,
    required List<String> initialPhases,
  }) : this._(
         branchKind: _ControllerCommitBranchKind.noEffects,
         changeSet: changeSet,
         initialPhases: initialPhases,
         commitCandidate: null,
         committedSelection: null,
         committedRevisionState: null,
         nextEpoch: null,
         nextStructuralRevision: null,
         nextBoundsRevision: null,
         nextVisualRevision: null,
         nextCommitRevision: null,
         shouldCommitSignals: false,
         shouldNotify: false,
         shouldMarkRepaint: false,
       );

  const _ControllerCommitPlan.effectsOnly({
    required ChangeSet changeSet,
    required List<String> initialPhases,
    required int? nextCommitRevision,
    required bool shouldCommitSignals,
    required bool shouldNotify,
  }) : this._(
         branchKind: _ControllerCommitBranchKind.effectsOnly,
         changeSet: changeSet,
         initialPhases: initialPhases,
         commitCandidate: null,
         committedSelection: null,
         committedRevisionState: null,
         nextEpoch: null,
         nextStructuralRevision: null,
         nextBoundsRevision: null,
         nextVisualRevision: null,
         nextCommitRevision: nextCommitRevision,
         shouldCommitSignals: shouldCommitSignals,
         shouldNotify: shouldNotify,
         shouldMarkRepaint: false,
       );

  const _ControllerCommitPlan.stateCommit({
    required ChangeSet changeSet,
    required List<String> initialPhases,
    required MutationCommitCandidate commitCandidate,
    required Set<NodeId> committedSelection,
    required RevisionAllocatorState committedRevisionState,
    required int nextEpoch,
    required int nextStructuralRevision,
    required int nextBoundsRevision,
    required int nextVisualRevision,
    required int nextCommitRevision,
    required bool shouldMarkRepaint,
  }) : this._(
         branchKind: _ControllerCommitBranchKind.stateCommit,
         changeSet: changeSet,
         initialPhases: initialPhases,
         commitCandidate: commitCandidate,
         committedSelection: committedSelection,
         committedRevisionState: committedRevisionState,
         nextEpoch: nextEpoch,
         nextStructuralRevision: nextStructuralRevision,
         nextBoundsRevision: nextBoundsRevision,
         nextVisualRevision: nextVisualRevision,
         nextCommitRevision: nextCommitRevision,
         shouldCommitSignals: true,
         shouldNotify: true,
         shouldMarkRepaint: shouldMarkRepaint,
       );

  final _ControllerCommitBranchKind branchKind;
  final ChangeSet changeSet;
  final List<String> initialPhases;
  final MutationCommitCandidate? commitCandidate;
  final Set<NodeId>? committedSelection;
  final RevisionAllocatorState? committedRevisionState;
  final int? nextEpoch;
  final int? nextStructuralRevision;
  final int? nextBoundsRevision;
  final int? nextVisualRevision;
  final int? nextCommitRevision;
  final bool shouldCommitSignals;
  final bool shouldNotify;
  final bool shouldMarkRepaint;
}
