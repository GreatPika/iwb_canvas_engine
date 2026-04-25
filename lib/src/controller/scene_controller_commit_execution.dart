import 'package:flutter/foundation.dart';

import '../core/nodes.dart';
import '../core/scene.dart';
import 'change_set.dart';
import 'committed_store_state.dart';
import 'internal/repaint_flag.dart';
import 'internal/signal_event.dart';
import 'internal/signals_buffer.dart';
import 'internal/spatial_index_cache.dart';
import 'scene_controller_commit_debug.dart';
import 'scene_controller_commit_plan.dart';
import 'scene_invariants.dart';
import 'store.dart';

final class SceneControllerWriteCommitResult {
  const SceneControllerWriteCommitResult({
    required this.committedSignals,
    required this.needsNotify,
  });

  final List<CommittedSignal> committedSignals;
  final bool needsNotify;
}

final class SceneControllerCommitExecutionContext {
  const SceneControllerCommitExecutionContext({
    required this.store,
    required this.signalsBuffer,
    required this.repaintFlag,
    required this.spatialIndexCache,
    required this.debugState,
  });

  final SceneStore store;
  final SignalsBuffer signalsBuffer;
  final RepaintFlag repaintFlag;
  final SpatialIndexCache spatialIndexCache;
  final SceneControllerCommitDebugState debugState;
}

SceneControllerWriteCommitResult executeControllerCommitPlan({
  required ControllerCommitPlan plan,
  required SceneControllerCommitExecutionContext context,
}) {
  return switch (plan) {
    ControllerEffectsOnlyCommitPlan() => _executeEffectsOnlyPlan(
      plan: plan,
      context: context,
    ),
    ControllerStateCommitPlan() => _executeStatePlan(
      plan: plan,
      context: context,
    ),
  };
}

SceneControllerWriteCommitResult _executeEffectsOnlyPlan({
  required ControllerEffectsOnlyCommitPlan plan,
  required SceneControllerCommitExecutionContext context,
}) {
  if (!context.signalsBuffer.writeHasBufferedSignals &&
      !context.repaintFlag.needsNotify) {
    return const SceneControllerWriteCommitResult(
      committedSignals: <CommittedSignal>[],
      needsNotify: false,
    );
  }

  var committedSignals = const <CommittedSignal>[];
  if (context.signalsBuffer.writeHasBufferedSignals) {
    final committedStoreState = CommittedStoreState(
      scene: context.store.sceneDoc,
      selectedNodeIds: context.store.selectedNodeIds,
      allNodeIds: context.store.allNodeIds,
      nodeLocator: context.store.nodeLocator,
      layerIndexById: context.store.layerIndexById,
      idGeneratorState: context.store.idGeneratorState,
      revisionState: context.store.revisionState,
      controllerEpoch: context.store.controllerEpoch,
      structuralRevision: context.store.structuralRevision,
      selectionRevision: context.store.selectionRevision,
      boundsRevision: context.store.boundsRevision,
      visualRevision: context.store.visualRevision,
      commitRevision: plan.nextCommitRevision,
    );
    _assertStoreInvariantsCandidate(
      state: committedStoreState,
      previousCommitRevision: context.store.commitRevision,
      previousSelectedNodeIds: context.store.selectedNodeIds,
      previousSelectionRevision: context.store.selectionRevision,
      previousScene: context.store.sceneDoc,
      changeSet: plan.changeSet,
      beforeInvariantPrecheckHook:
          context.debugState.beforeInvariantPrecheckHook,
    );
    committedSignals = context.signalsBuffer.writeTakeCommitted(
      commitRevision: committedStoreState.commitRevision,
    );
    context.store.commitRevision = committedStoreState.commitRevision;
  }

  return SceneControllerWriteCommitResult(
    committedSignals: committedSignals,
    needsNotify: context.repaintFlag.writeTakeNeedsNotify(),
  );
}

SceneControllerWriteCommitResult _executeStatePlan({
  required ControllerStateCommitPlan plan,
  required SceneControllerCommitExecutionContext context,
}) {
  final committedStoreState = plan.committedStoreState;
  _assertStoreInvariantsCandidate(
    state: committedStoreState,
    previousCommitRevision: context.store.commitRevision,
    previousSelectedNodeIds: context.store.selectedNodeIds,
    previousSelectionRevision: context.store.selectionRevision,
    previousScene: context.store.sceneDoc,
    changeSet: plan.changeSet,
    beforeInvariantPrecheckHook: context.debugState.beforeInvariantPrecheckHook,
  );

  context.debugState.beforeSpatialPrepareCommitHook?.call();
  final preparedSpatialCommit = context.spatialIndexCache.writePrepareCommit(
    scene: committedStoreState.scene,
    nodeLocator: committedStoreState.nodeLocator,
    layerIndexById: committedStoreState.layerIndexById,
    changeSet: plan.changeSet,
    controllerEpoch: committedStoreState.controllerEpoch,
    structuralRevision: committedStoreState.structuralRevision,
  );

  final committedSignals = context.signalsBuffer.writeTakeCommitted(
    commitRevision: committedStoreState.commitRevision,
  );

  _applyCommittedStore(
    store: context.store,
    committedStoreState: committedStoreState,
  );
  context.spatialIndexCache.writeApplyPreparedCommit(preparedSpatialCommit);

  context.repaintFlag.writeMarkNeedsRepaint();
  return SceneControllerWriteCommitResult(
    committedSignals: committedSignals,
    needsNotify: context.repaintFlag.writeTakeNeedsNotify(),
  );
}

void _assertStoreInvariantsCandidate({
  required CommittedStoreState state,
  required int previousCommitRevision,
  required Set<NodeId> previousSelectedNodeIds,
  required int previousSelectionRevision,
  required Scene previousScene,
  required ChangeSet changeSet,
  required void Function()? beforeInvariantPrecheckHook,
}) {
  assertCriticalTxnStoreInvariants(
    state: state,
    commitRevision: state.commitRevision,
    previousCommitRevision: previousCommitRevision,
    previousSelectedNodeIds: previousSelectedNodeIds,
    previousSelectionRevision: previousSelectionRevision,
    changeSet: changeSet,
    previousScene: previousScene,
  );
  if (!kDebugMode && !kProfileMode) {
    return;
  }
  assert(() {
    beforeInvariantPrecheckHook?.call();
    return true;
  }());
  debugAssertTxnStoreInvariants(state);
}

void _applyCommittedStore({
  required SceneStore store,
  required CommittedStoreState committedStoreState,
}) {
  store.sceneDoc = committedStoreState.scene;
  store.selectedNodeIds = committedStoreState.selectedNodeIds;
  store.allNodeIds = committedStoreState.allNodeIds;
  store.nodeLocator = committedStoreState.nodeLocator;
  store.layerIndexById = committedStoreState.layerIndexById;
  store.idGeneratorState = committedStoreState.idGeneratorState;
  store.revisionState = committedStoreState.revisionState;
  store.controllerEpoch = committedStoreState.controllerEpoch;
  store.structuralRevision = committedStoreState.structuralRevision;
  store.selectionRevision = committedStoreState.selectionRevision;
  store.boundsRevision = committedStoreState.boundsRevision;
  store.visualRevision = committedStoreState.visualRevision;
  store.commitRevision = committedStoreState.commitRevision;
}
