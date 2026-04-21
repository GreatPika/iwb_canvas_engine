import 'dart:ui';

import '../../core/action_events.dart';
import '../../contract/pointer_input.dart';
import '../../contract/scene_view_runtime.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import '../../controller/scene_store_controller.dart';
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

typedef SceneControllerGraph = ({
  SceneControllerInteractionRuntime interactionRuntime,
  SceneControllerInteractionAccess interactionAccess,
  SceneControllerInteraction interaction,
  SceneControllerSelection selection,
  SceneControllerScene scene,
  SceneViewRuntime sceneViewRuntime,
  SceneControllerInternalAccessRegistration internalAccessRegistration,
});

final class SceneControllerGraphRequest {
  const SceneControllerGraphRequest({
    required this.owner,
    required this.notifyListeners,
    required this.storeController,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readControllerEpoch,
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
  final PointerInputSettings? pointerSettings;
  final double? dragStartSlop;
  final bool clearSelectionOnDrawModeEnter;
  final MoveCommitDeltaResolver? moveCommitDeltaResolver;
}

SceneControllerGraph createSceneControllerGraph(
  SceneControllerGraphRequest request,
) {
  final graph = _assembleSceneControllerGraph(request);
  registerSceneControllerInternalAccess(
    request.owner,
    graph.internalAccessRegistration,
  );
  return graph;
}

SceneControllerGraph _assembleSceneControllerGraph(
  SceneControllerGraphRequest request,
) {
  final interactionConfig = _createInteractionConfig(request);
  late final SceneControllerInteractionRuntime interactionRuntime;
  final sceneViewRuntime = SceneControllerSceneViewRuntime(
    storeController: request.storeController,
    ownerListenable: request.owner,
    ensurePublicSideEffectAllowed: (operation, {allowAfterDispose = false}) =>
        interactionRuntime.ensurePublicSideEffectAllowed(
          operation,
          allowAfterDispose: allowAfterDispose,
        ),
    readSnapshot: request.readSnapshot,
    readSelectedNodeIds: request.readSelectedNodeIds,
    readControllerEpoch: request.readControllerEpoch,
    readInteraction: () => request.owner.interaction,
    captureFramePreview: () => interactionRuntime.captureFramePreview(),
    readInteractionRuntime: () => interactionRuntime,
  );
  interactionRuntime = _createInteractionRuntime(
    request: request,
    interactionConfig: interactionConfig,
    sceneViewRuntime: sceneViewRuntime,
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
  final interaction = SceneControllerInteractionOwner(interactionAccess);

  return (
    interactionRuntime: interactionRuntime,
    interactionAccess: interactionAccess,
    interaction: interaction,
    selection: SceneControllerSelectionOwner(
      runtime: interactionRuntime,
      mutations: selectionMutations,
    ),
    scene: SceneControllerSceneOwner(
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

void detachSceneControllerGraphInternalAccess(SceneController controller) {
  unregisterSceneControllerInternalAccess(controller);
}

Offset Function(NodeId nodeId) sceneControllerGraphPreviewDeltaResolver(
  SceneControllerGraph graph,
) {
  return graph.interactionRuntime.previewDeltaForNode;
}

Stream<ActionCommitted> sceneControllerGraphActions(
  SceneControllerGraph graph,
) {
  return graph.interactionRuntime.actions;
}

Stream<EditTextRequested> sceneControllerGraphEditTextRequests(
  SceneControllerGraph graph,
) {
  return graph.interactionRuntime.editTextRequests;
}

void sceneControllerGraphEnsurePublicSideEffectAllowed(
  SceneControllerGraph graph,
  String operation, {
  bool allowAfterDispose = false,
}) {
  graph.interactionRuntime.ensurePublicSideEffectAllowed(
    operation,
    allowAfterDispose: allowAfterDispose,
  );
}

bool sceneControllerGraphIsDisposed(SceneControllerGraph graph) {
  return graph.interactionRuntime.isDisposed;
}

void disposeSceneControllerGraph(SceneControllerGraph graph) {
  graph.interactionRuntime.dispose();
  final sceneViewRuntime = graph.sceneViewRuntime;
  if (sceneViewRuntime is SceneControllerSceneViewRuntime) {
    sceneViewRuntime.dispose();
  }
}

SceneControllerInteractionConfig _createInteractionConfig(
  SceneControllerGraphRequest request,
) {
  final interactionConfig = SceneControllerInteractionConfig(
    pointerSettings: request.pointerSettings,
    dragStartSlop: request.dragStartSlop,
  );
  validatePointerInputSettings(interactionConfig.pointerSettings);
  return interactionConfig;
}

SceneControllerInteractionRuntime _createInteractionRuntime({
  required SceneControllerGraphRequest request,
  required SceneControllerInteractionConfig interactionConfig,
  required SceneControllerSceneViewRuntime sceneViewRuntime,
}) {
  return createSceneControllerInteractionRuntime(
    request: SceneControllerInteractionRuntimeRequest(
      notifyPublicListeners: request.notifyListeners,
      notifySceneListeners: sceneViewRuntime.scheduleSceneRepaint,
      notifyOverlayListeners: sceneViewRuntime.scheduleOverlayRepaint,
      storeController: request.storeController,
      mutationAccess: SceneStoreControllerCommittedMutationAccess(
        request.storeController,
      ),
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
    interruptForExternalMutation:
        interactionRuntime.interruptForExternalMutation,
  );
}
