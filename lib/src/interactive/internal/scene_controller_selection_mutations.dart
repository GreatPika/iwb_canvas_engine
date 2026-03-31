import '../../contract/snapshot.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerSelectionMutations {
  const SceneControllerSelectionMutations({
    required this.mutations,
    required this.ensureExternalMutationAllowed,
  });

  final SceneControllerMutationBoundary mutations;
  final void Function(String operation) ensureExternalMutationAllowed;

  void setSelection(Iterable<NodeId> nodeIds) {
    ensureExternalMutationAllowed('setSelection');
    mutations.setSelection(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    ensureExternalMutationAllowed('toggleSelection');
    mutations.toggleSelection(nodeId);
  }

  void clearSelection() {
    ensureExternalMutationAllowed('clearSelection');
    mutations.clearSelection();
  }

  void selectAll({bool onlySelectable = true}) {
    ensureExternalMutationAllowed('selectAll');
    mutations.selectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    ensureExternalMutationAllowed('rotateSelection');
    mutations.rotateSelection(clockwise: clockwise, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    ensureExternalMutationAllowed('flipSelectionVertical');
    mutations.flipSelectionVertical(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    ensureExternalMutationAllowed('flipSelectionHorizontal');
    mutations.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    ensureExternalMutationAllowed('deleteSelection');
    mutations.deleteSelection(timestampMs: timestampMs);
  }
}
