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
import 'committed_store_state.dart';
import 'mutation_commit_preparer.dart';
import 'mutation_executor.dart';
import 'mutation_op.dart';
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
    _postCommitLifecycle = _ControllerPostCommitLifecycle(
      signalsBuffer: _signalsBuffer,
      notifyListeners: notifyListeners,
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
  late final _ControllerPostCommitLifecycle _postCommitLifecycle;

  bool _writeInProgress = false;
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

  late final SceneCommands commands = SceneCommands(_writeWithSceneWriter);
  late final MoveCommands move = MoveCommands(write);
  late final DrawCommands draw = DrawCommands(_writeWithSceneWriter);

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

    _postCommitLifecycle.dispatch(commitResult);
    return result;
  }

  T _writeWithSceneWriter<T>(T Function(SceneWriter writer) fn) {
    return write<T>((writer) => fn(writer as SceneWriter));
  }

  void writeReplaceScene(SceneSnapshot snapshot) {
    write<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }

  void requestRepaint() {
    _throwIfDisposed();
    _postCommitLifecycle.requestRepaint(
      repaintFlag: _repaintFlag,
      writeInProgress: _writeInProgress,
    );
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
    final preparedCommit = prepareMutationPreparedCommitResult(ctx);
    final changeSet = preparedCommit.changeSet;
    final commitCandidate = preparedCommit.commitCandidate;
    final hasSignals = _signalsBuffer.writeHasBufferedSignals;
    final hasRepaint = _repaintFlag.needsNotify;

    if (commitCandidate == null && !hasSignals && !hasRepaint) {
      return _NoEffectsControllerCommitPlan(
        changeSet: changeSet,
        initialPhases: initialPhases,
      );
    }

    if (commitCandidate == null) {
      return _EffectsOnlyControllerCommitPlan(
        changeSet: changeSet,
        initialPhases: initialPhases,
        nextCommitRevision: _store.commitRevision + 1,
        shouldCommitSignals: hasSignals,
        shouldNotify: hasRepaint,
      );
    }

    return _buildStateCommitPlan(
      changeSet: changeSet,
      initialPhases: initialPhases,
      commitCandidate: commitCandidate,
    );
  }

  _StateCommitControllerCommitPlan _buildStateCommitPlan({
    required ChangeSet changeSet,
    required List<String> initialPhases,
    required MutationCommitCandidate commitCandidate,
  }) {
    final committedSelection = changeSet.selectionChanged
        ? commitCandidate.selection
        : _store.selectedNodeIds;
    final committedRevisionState = resolvedCommittedRevisionAllocatorState(
      commitCandidate.revisionState,
    );
    return _StateCommitControllerCommitPlan(
      changeSet: changeSet,
      initialPhases: initialPhases,
      committedStoreState: CommittedStoreState.fromMutationCommitCandidate(
        candidate: commitCandidate,
        selectedNodeIds: committedSelection,
        revisionState: committedRevisionState,
        controllerEpoch: resolveNextControllerEpoch(
          currentEpoch: _store.controllerEpoch,
          documentReplaced: changeSet.documentReplaced,
          revisionState: commitCandidate.revisionState,
        ),
        structuralRevision:
            _store.structuralRevision + (changeSet.structuralChanged ? 1 : 0),
        boundsRevision:
            _store.boundsRevision + (changeSet.boundsChanged ? 1 : 0),
        visualRevision: _store.visualRevision + 1,
        commitRevision: _store.commitRevision + 1,
      ),
    );
  }

  _ControllerCommitExecution _executeControllerCommitPlan(
    _ControllerCommitPlan plan,
  ) {
    return switch (plan) {
      _NoEffectsControllerCommitPlan() => _ControllerCommitExecution(
        commitPhases: plan.initialPhases,
        commitResult: const _TxnWriteCommitResult(
          committedSignals: <CommittedSignal>[],
          needsNotify: false,
        ),
      ),
      _EffectsOnlyControllerCommitPlan() => _executeEffectsOnlyCommitPlan(plan),
      _StateCommitControllerCommitPlan() => _executeStateCommitPlan(plan),
    };
  }

  _ControllerCommitExecution _executeEffectsOnlyCommitPlan(
    _EffectsOnlyControllerCommitPlan plan,
  ) {
    var commitPhases = plan.initialPhases;
    var committedSignals = const <CommittedSignal>[];

    if (plan.shouldCommitSignals) {
      final committedStoreState = CommittedStoreState(
        scene: _store.sceneDoc,
        selectedNodeIds: _store.selectedNodeIds,
        allNodeIds: _store.allNodeIds,
        nodeLocator: _store.nodeLocator,
        idGeneratorState: _store.idGeneratorState,
        revisionState: _store.revisionState,
        controllerEpoch: _store.controllerEpoch,
        structuralRevision: _store.structuralRevision,
        boundsRevision: _store.boundsRevision,
        visualRevision: _store.visualRevision,
        commitRevision: plan.nextCommitRevision,
      );
      _assertStoreInvariantsCandidate(
        state: committedStoreState,
        previousCommitRevision: _store.commitRevision,
      );
      committedSignals = _signalsBuffer.writeTakeCommitted(
        commitRevision: committedStoreState.commitRevision,
      );
      _store.commitRevision = committedStoreState.commitRevision;
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
    _StateCommitControllerCommitPlan plan,
  ) {
    final committedStoreState = plan.committedStoreState;

    _assertStoreInvariantsCandidate(
      state: committedStoreState,
      previousCommitRevision: _store.commitRevision,
    );

    debugBeforeSpatialPrepareCommitHook?.call();
    final preparedSpatialCommit = _spatialIndexCache.writePrepareCommit(
      scene: committedStoreState.scene,
      nodeLocator: committedStoreState.nodeLocator,
      changeSet: plan.changeSet,
      controllerEpoch: committedStoreState.controllerEpoch,
    );

    final committedSignals = _signalsBuffer.writeTakeCommitted(
      commitRevision: committedStoreState.commitRevision,
    );

    _applyCommittedStore(committedStoreState);
    _spatialIndexCache.writeApplyPreparedCommit(preparedSpatialCommit);

    var commitPhases = <String>[
      ...plan.initialPhases,
      'spatial_index',
      'signals',
    ];
    _repaintFlag.writeMarkNeedsRepaint();
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

  void _applyCommittedStore(CommittedStoreState committedStoreState) {
    _store.sceneDoc = committedStoreState.scene;
    final committedSelection = committedStoreState.selectedNodeIds;
    if (!identical(_store.selectedNodeIds, committedSelection)) {
      _store.selectedNodeIds = committedSelection;
      _selectedNodeIdsView = UnmodifiableSetView<NodeId>(committedSelection);
    }
    _store.allNodeIds = committedStoreState.allNodeIds;
    _store.nodeLocator = committedStoreState.nodeLocator;
    _store.idGeneratorState = committedStoreState.idGeneratorState;
    _store.revisionState = committedStoreState.revisionState;
    _store.controllerEpoch = committedStoreState.controllerEpoch;
    _store.structuralRevision = committedStoreState.structuralRevision;
    _store.boundsRevision = committedStoreState.boundsRevision;
    _store.visualRevision = committedStoreState.visualRevision;
    _store.commitRevision = committedStoreState.commitRevision;
  }

  void _debugCaptureTxnCloneStats(TxnContext ctx) {
    _debugLastSceneShallowClones = ctx.debugSceneShallowClones;
    _debugLastLayerShallowClones = ctx.debugLayerShallowClones;
    _debugLastNodeClones = ctx.debugNodeClones;
    _debugLastNodeIdSetMaterializations = ctx.debugNodeIdSetMaterializations;
    _debugLastNodeLocatorMaterializations =
        ctx.debugNodeLocatorMaterializations;
  }

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('Controller is disposed.');
    }
  }

  void _assertStoreInvariantsCandidate({
    required CommittedStoreState state,
    required int previousCommitRevision,
  }) {
    assertCriticalTxnStoreInvariants(
      state: state,
      commitRevision: state.commitRevision,
      previousCommitRevision: previousCommitRevision,
    );
    if (!kDebugMode && !kProfileMode) {
      return;
    }
    assert(() {
      debugBeforeInvariantPrecheckHook?.call();
      return true;
    }());
    debugAssertTxnStoreInvariants(state);
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
    _postCommitLifecycle.dispose();
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

final class _ControllerPostCommitLifecycle {
  _ControllerPostCommitLifecycle({
    required SignalsBuffer signalsBuffer,
    required VoidCallback notifyListeners,
  }) : _signalsBuffer = signalsBuffer,
       _notifyListeners = notifyListeners;

  final SignalsBuffer _signalsBuffer;
  final VoidCallback _notifyListeners;
  bool _notifyScheduled = false;
  bool _notifyPending = false;
  bool _isDisposed = false;

  void requestRepaint({
    required RepaintFlag repaintFlag,
    required bool writeInProgress,
  }) {
    repaintFlag.writeMarkNeedsRepaint();
    if (writeInProgress) {
      return;
    }
    if (repaintFlag.writeTakeNeedsNotify()) {
      _scheduleNotify();
    }
  }

  void dispatch(_TxnWriteCommitResult commitResult) {
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
    scheduleMicrotask(_scheduleNotify);
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
      _notifyListeners();
    });
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _notifyPending = false;
    _notifyScheduled = false;
  }
}

class _ControllerCommitExecution {
  const _ControllerCommitExecution({
    required this.commitPhases,
    required this.commitResult,
  });

  final List<String> commitPhases;
  final _TxnWriteCommitResult commitResult;
}

sealed class _ControllerCommitPlan {
  const _ControllerCommitPlan({
    required this.changeSet,
    required this.initialPhases,
  });

  final ChangeSet changeSet;
  final List<String> initialPhases;
}

final class _NoEffectsControllerCommitPlan extends _ControllerCommitPlan {
  const _NoEffectsControllerCommitPlan({
    required super.changeSet,
    required super.initialPhases,
  });
}

final class _EffectsOnlyControllerCommitPlan extends _ControllerCommitPlan {
  const _EffectsOnlyControllerCommitPlan({
    required super.changeSet,
    required super.initialPhases,
    required this.nextCommitRevision,
    required this.shouldCommitSignals,
    required this.shouldNotify,
  });

  final int nextCommitRevision;
  final bool shouldCommitSignals;
  final bool shouldNotify;
}

final class _StateCommitControllerCommitPlan extends _ControllerCommitPlan {
  const _StateCommitControllerCommitPlan({
    required super.changeSet,
    required super.initialPhases,
    required this.committedStoreState,
  });

  final CommittedStoreState committedStoreState;
}
