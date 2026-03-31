import '../../contract/snapshot.dart';
import '../../controller/scene_controller.dart';

final class SceneControllerSelectionMutations {
  const SceneControllerSelectionMutations({
    required this.core,
    required this.ensureExternalMutationAllowed,
    required this.rotateSelectionState,
    required this.flipSelectionVerticalState,
    required this.flipSelectionHorizontalState,
    required this.deleteSelectionState,
  });

  final SceneControllerCore core;
  final void Function(String operation) ensureExternalMutationAllowed;
  final void Function({required bool clockwise, int? timestampMs})
  rotateSelectionState;
  final void Function({int? timestampMs}) flipSelectionVerticalState;
  final void Function({int? timestampMs}) flipSelectionHorizontalState;
  final void Function({int? timestampMs}) deleteSelectionState;

  void setSelection(Iterable<NodeId> nodeIds) {
    ensureExternalMutationAllowed('setSelection');
    core.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    ensureExternalMutationAllowed('toggleSelection');
    core.commands.writeSelectionToggle(nodeId);
  }

  void clearSelection() {
    ensureExternalMutationAllowed('clearSelection');
    core.commands.writeSelectionClear();
  }

  void selectAll({bool onlySelectable = true}) {
    ensureExternalMutationAllowed('selectAll');
    core.commands.writeSelectionSelectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    ensureExternalMutationAllowed('rotateSelection');
    rotateSelectionState(clockwise: clockwise, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    ensureExternalMutationAllowed('flipSelectionVertical');
    flipSelectionVerticalState(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    ensureExternalMutationAllowed('flipSelectionHorizontal');
    flipSelectionHorizontalState(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    ensureExternalMutationAllowed('deleteSelection');
    deleteSelectionState(timestampMs: timestampMs);
  }
}
