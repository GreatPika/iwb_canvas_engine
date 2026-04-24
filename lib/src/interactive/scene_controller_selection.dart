import '../contract/snapshot.dart';
import 'internal/scene_controller_interaction_runtime.dart';
import 'internal/scene_controller_mutation_boundary.dart';

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
    required SceneControllerMutationBoundary mutationBoundary,
  }) : _runtime = runtime,
       _mutationBoundary = mutationBoundary;

  final SceneControllerInteractionRuntime _runtime;
  final SceneControllerMutationBoundary _mutationBoundary;

  @override
  void setSelection(Iterable<NodeId> nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
    _ensureExternalMutationAllowed('setSelection');
    _mutationBoundary.setSelection(nodeIds);
  }

  @override
  void toggleSelection(NodeId nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
    _ensureExternalMutationAllowed('toggleSelection');
    _mutationBoundary.toggleSelection(nodeId);
  }

  @override
  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
    _ensureExternalMutationAllowed('clearSelection');
    _mutationBoundary.clearSelection();
  }

  @override
  void selectAll({bool onlySelectable = true}) {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
    _ensureExternalMutationAllowed('selectAll');
    _mutationBoundary.selectAll(onlySelectable: onlySelectable);
  }

  @override
  void rotateSelection({required bool clockwise, int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('rotateSelection');
    _ensureExternalMutationAllowed('rotateSelection');
    _mutationBoundary.rotateSelection(
      clockwise: clockwise,
      timestampMs: timestampMs,
    );
  }

  @override
  void flipSelectionVertical({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionVertical');
    _ensureExternalMutationAllowed('flipSelectionVertical');
    _mutationBoundary.flipSelectionVertical(timestampMs: timestampMs);
  }

  @override
  void flipSelectionHorizontal({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionHorizontal');
    _ensureExternalMutationAllowed('flipSelectionHorizontal');
    _mutationBoundary.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  @override
  void deleteSelection({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('deleteSelection');
    _ensureExternalMutationAllowed('deleteSelection');
    _mutationBoundary.deleteSelection(timestampMs: timestampMs);
  }

  void _ensureExternalMutationAllowed(String operation) {
    _runtime.ensureExternalMutationAllowed(operation);
  }
}
