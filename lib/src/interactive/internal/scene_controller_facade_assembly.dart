import 'package:flutter/foundation.dart';

import '../../contract/snapshot.dart';
import '../../controller/scene_controller.dart';
import '../../core/pointer_input.dart';
import 'scene_controller_interaction_access.dart';
import 'scene_controller_interaction_config.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_scene_access.dart';
import 'scene_controller_scene_mutations.dart';
import 'scene_controller_selection_access.dart';
import 'scene_controller_selection_mutations.dart';
import '../scene_controller_interaction.dart';
import '../scene_controller_scene.dart';
import '../scene_controller_selection.dart';

typedef SceneControllerFacadeAssembly = ({
  SceneControllerInteractionRuntime interactionRuntime,
  SceneControllerInteractionAccess interactionAccess,
  SceneControllerInteraction interaction,
  SceneControllerSelection selection,
  SceneControllerScene scene,
});

final class SceneControllerFacadeRequest {
  const SceneControllerFacadeRequest({
    required this.owner,
    required this.notifyListeners,
    required this.core,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.pointerSettings,
    required this.dragStartSlop,
    required this.clearSelectionOnDrawModeEnter,
    required this.moveCommitDeltaResolver,
  });

  final Listenable owner;
  final void Function() notifyListeners;
  final SceneControllerCore core;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final PointerInputSettings? pointerSettings;
  final double? dragStartSlop;
  final bool clearSelectionOnDrawModeEnter;
  final MoveCommitDeltaResolver? moveCommitDeltaResolver;
}

SceneControllerFacadeAssembly assembleSceneControllerFacade(
  SceneControllerFacadeRequest request,
) {
  final interactionConfig = _createInteractionConfig(request);
  final interactionRuntime = _createInteractionRuntime(
    request: request,
    interactionConfig: interactionConfig,
  );
  final selectionMutations = _createSelectionMutations(
    core: request.core,
    interactionRuntime: interactionRuntime,
  );
  final sceneMutations = _createSceneMutations(
    request: request,
    core: request.core,
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

  return (
    interactionRuntime: interactionRuntime,
    interactionAccess: interactionAccess,
    interaction: SceneControllerInteraction(interactionAccess),
    selection: SceneControllerSelection(
      SceneControllerSelectionAccessAdapter(
        runtime: interactionRuntime,
        mutations: selectionMutations,
      ),
    ),
    scene: SceneControllerScene(
      SceneControllerSceneAccessAdapter(
        ensurePublicSideEffectAllowedCallback:
            interactionRuntime.ensurePublicSideEffectAllowed,
        mutations: sceneMutations,
      ),
    ),
  );
}

SceneControllerInteractionConfig _createInteractionConfig(
  SceneControllerFacadeRequest request,
) {
  final interactionConfig = SceneControllerInteractionConfig(
    pointerSettings: request.pointerSettings,
    dragStartSlop: request.dragStartSlop,
  );
  validatePointerInputSettings(interactionConfig.pointerSettings);
  return interactionConfig;
}

SceneControllerInteractionRuntime _createInteractionRuntime({
  required SceneControllerFacadeRequest request,
  required SceneControllerInteractionConfig interactionConfig,
}) {
  return createSceneControllerInteractionRuntime(
    request: SceneControllerInteractionRuntimeRequest(
      notifyListeners: request.notifyListeners,
      core: request.core,
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
  required SceneControllerCore core,
  required SceneControllerInteractionRuntime interactionRuntime,
}) {
  return SceneControllerSelectionMutations(
    core: core,
    rotateSelectionState: interactionRuntime.rotateSelection,
    flipSelectionVerticalState: interactionRuntime.flipSelectionVertical,
    flipSelectionHorizontalState: interactionRuntime.flipSelectionHorizontal,
    deleteSelectionState: interactionRuntime.deleteSelection,
  );
}

SceneControllerSceneMutations _createSceneMutations({
  required SceneControllerFacadeRequest request,
  required SceneControllerCore core,
  required SceneControllerInteractionRuntime interactionRuntime,
}) {
  return SceneControllerSceneMutations(
    core: core,
    emitAction: interactionRuntime.emitAction,
    resolveTimestampMs: interactionRuntime.resolveTimestampMs,
    resetInteractiveState: interactionRuntime.resetInteractiveState,
    clearPointerNormalizationState:
        interactionRuntime.clearPointerNormalizationState,
    clearSceneSelectionState: interactionRuntime.clearSceneSelectionState,
    readSnapshot: request.readSnapshot,
  );
}
