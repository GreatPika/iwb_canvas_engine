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
import 'scene_controller_interaction_config.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_scene_view_runtime.dart';

final class SceneControllerGraphHandle {
  SceneControllerGraphHandle({
    required SceneController owner,
    required SceneStoreController storeController,
    required SceneControllerInteractionRuntime interactionRuntime,
    required this.interaction,
    required this.selection,
    required this.scene,
    required this.sceneViewRuntime,
    required SceneControllerInternalAccessRegistration
    internalAccessRegistration,
  }) : _owner = owner,
       _storeController = storeController,
       _interactionRuntime = interactionRuntime,
       _internalAccessRegistration = internalAccessRegistration;

  final SceneController _owner;
  final SceneStoreController _storeController;
  final SceneControllerInteractionRuntime _interactionRuntime;
  final SceneControllerInteraction interaction;
  final SceneControllerSelection selection;
  final SceneControllerScene scene;
  final SceneViewRuntime sceneViewRuntime;
  final SceneControllerInternalAccessRegistration _internalAccessRegistration;

  SceneControllerInternalAccessRegistration get internalAccessRegistration =>
      _internalAccessRegistration;

  SceneSnapshot get snapshot => _storeController.snapshot;

  Set<NodeId> get selectedNodeIds => _storeController.selectedNodeIds;

  int get controllerEpoch => _storeController.controllerEpoch;

  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      _internalAccessRegistration.movePreviewRead.previewDeltaForNode;

  Stream<ActionCommitted> get actions => _interactionRuntime.actions;

  Stream<EditTextRequested> get editTextRequests =>
      _interactionRuntime.editTextRequests;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {
    _interactionRuntime.ensurePublicSideEffectAllowed(
      operation,
      allowAfterDispose: allowAfterDispose,
    );
  }

  bool dispose() {
    if (_interactionRuntime.isDisposed) {
      return false;
    }
    _storeController.dispose();
    _interactionRuntime.dispose();
    final runtime = sceneViewRuntime;
    if (runtime is SceneControllerSceneViewRuntime) {
      runtime.dispose();
    }
    unregisterSceneControllerInternalAccess(_owner);
    return true;
  }
}

final class SceneControllerGraphRequest {
  const SceneControllerGraphRequest({
    required this.owner,
    required this.notifyListeners,
    required this.initialSnapshot,
    required this.pointerSettings,
    required this.dragStartSlop,
    required this.clearSelectionOnDrawModeEnter,
    required this.moveCommitDeltaResolver,
    required this.textFontFamilyByDefault,
  });

  final SceneController owner;
  final void Function() notifyListeners;
  final SceneSnapshot? initialSnapshot;
  final PointerInputSettings? pointerSettings;
  final double? dragStartSlop;
  final bool clearSelectionOnDrawModeEnter;
  final MoveCommitDeltaResolver? moveCommitDeltaResolver;
  final String? textFontFamilyByDefault;
}

SceneControllerGraphHandle createSceneControllerGraph(
  SceneControllerGraphRequest request,
) {
  final graph = _assembleSceneControllerGraph(request);
  registerSceneControllerInternalAccess(
    request.owner,
    graph.internalAccessRegistration,
  );
  return graph;
}

SceneControllerGraphHandle _assembleSceneControllerGraph(
  SceneControllerGraphRequest request,
) {
  final storeController = SceneStoreController(
    initialSnapshot: request.initialSnapshot,
    textFontFamilyByDefault: request.textFontFamilyByDefault,
  );
  final interactionConfig = _createInteractionConfig(request);
  late final SceneControllerInteractionRuntime interactionRuntime;
  final sceneViewRuntime = SceneControllerSceneViewRuntime(
    storeController: storeController,
    ownerListenable: request.owner,
    ensurePublicSideEffectAllowed: (operation, {allowAfterDispose = false}) =>
        interactionRuntime.ensurePublicSideEffectAllowed(
          operation,
          allowAfterDispose: allowAfterDispose,
        ),
    readSnapshot: () => storeController.snapshot,
    readSelectedNodeIds: () => storeController.selectedNodeIds,
    readControllerEpoch: () => storeController.controllerEpoch,
    readInteraction: () => request.owner.interaction,
    movePreviewRead: () => interactionRuntime.movePreviewRead,
    readInteractionRuntime: () => interactionRuntime,
  );
  interactionRuntime = _createInteractionRuntime(
    request: request,
    interactionConfig: interactionConfig,
    sceneViewRuntime: sceneViewRuntime,
    storeController: storeController,
  );
  final interaction = SceneControllerInteractionOwner(
    ownerListenable: request.owner,
    config: interactionConfig,
    runtime: interactionRuntime,
    clearSelectionOnDrawModeEnter: request.clearSelectionOnDrawModeEnter,
    hasSelection: () => storeController.selectedNodeIds.isNotEmpty,
    clearSelectionState: () {
      interactionRuntime.ensureExternalMutationAllowed('clearSelection');
      interactionRuntime.mutationBoundary.clearSelection();
    },
  );

  return SceneControllerGraphHandle(
    owner: request.owner,
    storeController: storeController,
    interactionRuntime: interactionRuntime,
    interaction: interaction,
    selection: SceneControllerSelectionOwner(
      runtime: interactionRuntime,
      mutationBoundary: interactionRuntime.mutationBoundary,
    ),
    scene: SceneControllerSceneOwner(
      runtime: interactionRuntime,
      mutationBoundary: interactionRuntime.mutationBoundary,
    ),
    sceneViewRuntime: sceneViewRuntime,
    internalAccessRegistration: SceneControllerInternalAccessRegistration(
      readEpoch: () => storeController.controllerEpoch,
      movePreviewRead: interactionRuntime.movePreviewRead,
      setBeforePointerDispatchHook:
          interactionRuntime.setBeforePointerDispatchHook,
      runMoveCommitDeltaResolverForTest:
          interactionRuntime.runMoveCommitDeltaResolver,
      readInteractionRuntimeForTest: () => interactionRuntime,
      readCommittedSnapshotForTest: () => storeController.snapshot,
      readActiveEraserPointsLength: () =>
          interactionRuntime.activeEraserPointsLength,
      readEraserSpatialQueryCount: () =>
          interactionRuntime.eraserSpatialQueryCount,
      readEraserPreciseSegmentCheckCount: () =>
          interactionRuntime.eraserPreciseSegmentCheckCount,
      readEraserProjectedPointCount: () =>
          interactionRuntime.eraserProjectedPointCount,
    ),
  );
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
  required SceneStoreController storeController,
}) {
  return createSceneControllerInteractionRuntime(
    request: SceneControllerInteractionRuntimeRequest(
      notifyPublicListeners: request.notifyListeners,
      notifySceneListeners: sceneViewRuntime.scheduleSceneRepaint,
      notifyOverlayListeners: sceneViewRuntime.scheduleOverlayRepaint,
      storeController: storeController,
      mutationAccess: SceneStoreControllerCommittedMutationAccess(
        storeController,
      ),
      readSnapshot: () => storeController.snapshot,
      readSelectedNodeIds: () => storeController.selectedNodeIds,
      readMode: () => interactionConfig.mode,
      readDragStartSlop: interactionConfig.dragStartSlop,
      readDrawStyle: interactionConfig.currentDrawStyle,
      requireFiniteOffset: SceneControllerInteractionConfig.requireFiniteOffset,
      moveCommitDeltaResolver: request.moveCommitDeltaResolver,
    ),
  );
}
