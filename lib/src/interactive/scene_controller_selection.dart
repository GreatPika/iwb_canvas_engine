import '../contract/snapshot.dart';
import 'internal/scene_controller_selection_access.dart';

class SceneControllerSelection {
  SceneControllerSelection(this._access);

  final SceneControllerSelectionAccess _access;

  void setSelection(Iterable<NodeId> nodeIds) {
    _access.ensurePublicSideEffectAllowed('setSelection');
    _access.ensureExternalSelectionMutationAllowed('setSelection');
    _access.setSelection(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    _access.ensurePublicSideEffectAllowed('toggleSelection');
    _access.ensureExternalSelectionMutationAllowed('toggleSelection');
    _access.toggleSelection(nodeId);
  }

  void clearSelection() {
    _access.ensurePublicSideEffectAllowed('clearSelection');
    _access.ensureExternalSelectionMutationAllowed('clearSelection');
    _access.clearSelection();
  }

  void selectAll({bool onlySelectable = true}) {
    _access.ensurePublicSideEffectAllowed('selectAll');
    _access.ensureExternalSelectionMutationAllowed('selectAll');
    _access.selectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    _access.ensurePublicSideEffectAllowed('rotateSelection');
    _access.rotateSelection(clockwise: clockwise, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    _access.ensurePublicSideEffectAllowed('flipSelectionVertical');
    _access.flipSelectionVertical(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    _access.ensurePublicSideEffectAllowed('flipSelectionHorizontal');
    _access.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    _access.ensurePublicSideEffectAllowed('deleteSelection');
    _access.deleteSelection(timestampMs: timestampMs);
  }
}
