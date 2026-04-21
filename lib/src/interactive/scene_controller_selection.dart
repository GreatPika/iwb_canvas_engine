import '../contract/snapshot.dart';
import 'internal/scene_controller_interaction_runtime.dart';
import 'internal/scene_controller_selection_mutations.dart';

abstract interface class SceneControllerSelection {
  void setSelection(Iterable<NodeId> nodeIds);
  void toggleSelection(NodeId nodeId);
  void clearSelection();
  void selectAll({bool onlySelectable = true});
  void rotateSelection({required bool clockwise, int? timestampMs});
  void flipSelectionVertical({int? timestampMs});
  void flipSelectionHorizontal({int? timestampMs});
  void deleteSelection({int? timestampMs});
}

class SceneControllerSelectionOwner implements SceneControllerSelection {
  const SceneControllerSelectionOwner({
    required SceneControllerInteractionRuntime runtime,
    required SceneControllerSelectionMutations mutations,
  }) : _runtime = runtime,
       _mutations = mutations;

  final SceneControllerInteractionRuntime _runtime;
  final SceneControllerSelectionMutations _mutations;

  @override
  void setSelection(Iterable<NodeId> nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
    _mutations.setSelection(nodeIds);
  }

  @override
  void toggleSelection(NodeId nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
    _mutations.toggleSelection(nodeId);
  }

  @override
  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
    _mutations.clearSelection();
  }

  @override
  void selectAll({bool onlySelectable = true}) {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
    _mutations.selectAll(onlySelectable: onlySelectable);
  }

  @override
  void rotateSelection({required bool clockwise, int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('rotateSelection');
    _mutations.rotateSelection(clockwise: clockwise, timestampMs: timestampMs);
  }

  @override
  void flipSelectionVertical({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionVertical');
    _mutations.flipSelectionVertical(timestampMs: timestampMs);
  }

  @override
  void flipSelectionHorizontal({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionHorizontal');
    _mutations.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  @override
  void deleteSelection({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('deleteSelection');
    _mutations.deleteSelection(timestampMs: timestampMs);
  }
}
