import '../../contract/snapshot.dart';
import '../../controller/scene_controller.dart';

final class SceneControllerSelectionMutations {
  const SceneControllerSelectionMutations({
    required this.core,
    required this.rotateSelectionState,
    required this.flipSelectionVerticalState,
    required this.flipSelectionHorizontalState,
    required this.deleteSelectionState,
  });

  final SceneControllerCore core;
  final void Function({required bool clockwise, int? timestampMs})
  rotateSelectionState;
  final void Function({int? timestampMs}) flipSelectionVerticalState;
  final void Function({int? timestampMs}) flipSelectionHorizontalState;
  final void Function({int? timestampMs}) deleteSelectionState;

  void setSelection(Iterable<NodeId> nodeIds) {
    core.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    core.commands.writeSelectionToggle(nodeId);
  }

  void clearSelection() {
    core.commands.writeSelectionClear();
  }

  void selectAll({bool onlySelectable = true}) {
    core.commands.writeSelectionSelectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    rotateSelectionState(clockwise: clockwise, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    flipSelectionVerticalState(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    flipSelectionHorizontalState(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    deleteSelectionState(timestampMs: timestampMs);
  }
}
