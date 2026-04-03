import 'dart:ui';

import '../../core/action_events.dart';
import '../../contract/scene_view_runtime.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_store_controller.dart';
import '../../core/pointer_input.dart';
import '../scene_controller.dart';
import '../scene_controller_interaction.dart';
import '../scene_controller_scene.dart';
import '../scene_controller_selection.dart';
import 'scene_controller_internal_access.dart';
import 'scene_controller_interaction_access.dart';
import 'scene_controller_interaction_config.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_scene_view_runtime.dart';
import 'scene_controller_scene_mutations.dart';
import 'scene_controller_selection_mutations.dart';

typedef SceneControllerOwners = ({
  SceneControllerInteractionRuntime interactionRuntime,
  SceneControllerInteractionAccess interactionAccess,
  SceneControllerInteraction interaction,
  SceneControllerSelection selection,
  SceneControllerScene scene,
  SceneViewRuntime sceneViewRuntime,
  SceneControllerInternalAccessRegistration internalAccessRegistration,
});

final class SceneControllerOwnersRequest {
  const SceneControllerOwnersRequest({
    required this.owner,
    required this.notifyListeners,
    required this.storeController,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readControllerEpoch,
    required this.readPreviewDeltaResolver,
    required this.pointerSettings,
    required this.dragStartSlop,
    required this.clearSelectionOnDrawModeEnter,
    required this.moveCommitDeltaResolver,
  });

  final SceneController owner;
  final void Function() notifyListeners;
  final SceneStoreController storeController;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final int Function() readControllerEpoch;
  final Offset Function(NodeId nodeId) Function() readPreviewDeltaResolver;
  final PointerInputSettings? pointerSettings;
  final double? dragStartSlop;
  final bool clearSelectionOnDrawModeEnter;
  final MoveCommitDeltaResolver? moveCommitDeltaResolver;
}

SceneControllerOwners createSceneControllerOwners(
  SceneControllerOwnersRequest request,
) {
  final owners = _assembleSceneControllerOwners(request);
  registerSceneControllerInternalAccess(
    request.owner,
    owners.internalAccessRegistration,
  );
  return owners;
}

SceneControllerOwners _assembleSceneControllerOwners(
  SceneControllerOwnersRequest request,
) {
  final interactionConfig = _createInteractionConfig(request);
  final interactionRuntime = _createInteractionRuntime(
    request: request,
    interactionConfig: interactionConfig,
  );
  final selectionMutations = _createSelectionMutations(
    interactionRuntime: interactionRuntime,
  );
  final sceneMutations = _createSceneMutations(
    interactionRuntime: interactionRuntime,
  );
  final interactionAccess = SceneControllerInteractionContext(
    owner: request.owner,
    config: interactionConfig,
    runtime: interactionRuntime,
    readSnapshot: request.readSnapshot,
    hasSelectionState: () => request.readSelectedNodeIds().isNotEmpty,
    clearSelectionState: selectionMutations.clearSelection,
    clearSelectionOnDrawModeEnter: request.clearSelectionOnDrawModeEnter,
  );
  final interaction = SceneControllerInteraction(interactionAccess);
  final sceneViewRuntime = SceneControllerSceneViewRuntime(
    ownerListenable: request.owner,
    ensurePublicSideEffectAllowed:
        interactionRuntime.ensurePublicSideEffectAllowed,
    readSnapshot: request.readSnapshot,
    readSelectedNodeIds: request.readSelectedNodeIds,
    readControllerEpoch: request.readControllerEpoch,
    readPreviewDeltaResolver: request.readPreviewDeltaResolver,
    readInteraction: () => request.owner.interaction,
  );

  return (
    interactionRuntime: interactionRuntime,
    interactionAccess: interactionAccess,
    interaction: interaction,
    selection: SceneControllerSelection(
      runtime: interactionRuntime,
      mutations: selectionMutations,
    ),
    scene: SceneControllerScene(
      ensurePublicSideEffectAllowed:
          interactionRuntime.ensurePublicSideEffectAllowed,
      mutations: sceneMutations,
    ),
    sceneViewRuntime: sceneViewRuntime,
    internalAccessRegistration: SceneControllerInternalAccessRegistration(
      readEpoch: request.readControllerEpoch,
      previewDeltaForNode: interactionRuntime.previewDeltaForNode,
      setBeforePointerDispatchHook:
          interactionRuntime.setBeforePointerDispatchHook,
      runMoveCommitDeltaResolverForTest:
          interactionRuntime.runMoveCommitDeltaResolver,
      readInteractionAccessForTest: () => interactionAccess,
      readActiveEraserPointsLength: () =>
          interactionRuntime.activeEraserPointsLength,
      readEraserSpatialQueryCount: () =>
          interactionRuntime.eraserSpatialQueryCount,
      readEraserPreciseSegmentCheckCount: () =>
          interactionRuntime.eraserPreciseSegmentCheckCount,
    ),
  );
}

void detachSceneControllerOwnersInternalAccess(SceneController controller) {
  unregisterSceneControllerInternalAccess(controller);
}

Offset Function(NodeId nodeId) sceneControllerOwnersPreviewDeltaResolver(
  SceneControllerOwners owners,
) {
  return owners.interactionRuntime.previewDeltaForNode;
}

Stream<ActionCommitted> sceneControllerOwnersActions(
  SceneControllerOwners owners,
) {
  return owners.interactionRuntime.actions;
}

Stream<EditTextRequested> sceneControllerOwnersEditTextRequests(
  SceneControllerOwners owners,
) {
  return owners.interactionRuntime.editTextRequests;
}

void sceneControllerOwnersEnsurePublicSideEffectAllowed(
  SceneControllerOwners owners,
  String operation, {
  bool allowAfterDispose = false,
}) {
  owners.interactionRuntime.ensurePublicSideEffectAllowed(
    operation,
    allowAfterDispose: allowAfterDispose,
  );
}

bool sceneControllerOwnersAreDisposed(SceneControllerOwners owners) {
  return owners.interactionRuntime.isDisposed;
}

void resetSceneControllerOwnersInteractiveState(SceneControllerOwners owners) {
  owners.interactionRuntime.resetInteractiveState();
}

void disposeSceneControllerOwners(SceneControllerOwners owners) {
  owners.interactionRuntime.dispose();
}

SceneControllerInteractionConfig _createInteractionConfig(
  SceneControllerOwnersRequest request,
) {
  final interactionConfig = SceneControllerInteractionConfig(
    pointerSettings: request.pointerSettings,
    dragStartSlop: request.dragStartSlop,
  );
  validatePointerInputSettings(interactionConfig.pointerSettings);
  return interactionConfig;
}

SceneControllerInteractionRuntime _createInteractionRuntime({
  required SceneControllerOwnersRequest request,
  required SceneControllerInteractionConfig interactionConfig,
}) {
  return createSceneControllerInteractionRuntime(
    request: SceneControllerInteractionRuntimeRequest(
      notifyListeners: request.notifyListeners,
      storeController: request.storeController,
      readSnapshot: request.readSnapshot,
      readSelectedNodeIds: request.readSelectedNodeIds,
      readMode: () => interactionConfig.mode,
      readDragStartSlop: interactionConfig.dragStartSlop,
      readDrawStyle: interactionConfig.currentDrawStyle,
      requireFiniteOffset: SceneControllerInteractionConfig.requireFiniteOffset,
      moveCommitDeltaResolver: request.moveCommitDeltaResolver,
    ),
  );
}

SceneControllerSelectionMutations _createSelectionMutations({
  required SceneControllerInteractionRuntime interactionRuntime,
}) {
  return SceneControllerSelectionMutations(
    mutations: interactionRuntime.mutationBoundary,
    ensureExternalMutationAllowed:
        interactionRuntime.ensureExternalMutationAllowed,
  );
}

SceneControllerSceneMutations _createSceneMutations({
  required SceneControllerInteractionRuntime interactionRuntime,
}) {
  return SceneControllerSceneMutations(
    mutations: interactionRuntime.mutationBoundary,
    ensureExternalMutationAllowed:
        interactionRuntime.ensureExternalMutationAllowed,
    resetActiveGestureBeforeExternalMutation:
        interactionRuntime.resetActiveGestureBeforeExternalMutation,
  );
}
