import '../contract/snapshot.dart';
import 'internal/scene_controller_interaction_runtime.dart';
import 'internal/scene_controller_selection_mutations.dart';

class SceneControllerSelection {
  const SceneControllerSelection({
    required SceneControllerInteractionRuntime runtime,
    required SceneControllerSelectionMutations mutations,
  }) : _runtime = runtime,
       _mutations = mutations;

  final SceneControllerInteractionRuntime _runtime;
  final SceneControllerSelectionMutations _mutations;

  void setSelection(Iterable<NodeId> nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
    _runtime.ensureExternalSelectionMutationAllowed('setSelection');
    _mutations.setSelection(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
    _runtime.ensureExternalSelectionMutationAllowed('toggleSelection');
    _mutations.toggleSelection(nodeId);
  }

  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
    _runtime.ensureExternalSelectionMutationAllowed('clearSelection');
    _mutations.clearSelection();
  }

  void selectAll({bool onlySelectable = true}) {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
    _runtime.ensureExternalSelectionMutationAllowed('selectAll');
    _mutations.selectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('rotateSelection');
    _mutations.rotateSelection(clockwise: clockwise, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionVertical');
    _mutations.flipSelectionVertical(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionHorizontal');
    _mutations.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('deleteSelection');
    _mutations.deleteSelection(timestampMs: timestampMs);
  }
}
