import '../../contract/snapshot.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_selection_mutations.dart';

abstract interface class SceneControllerSelectionAccess {
  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  });

  void ensureExternalSelectionMutationAllowed(String operation);

  void setSelection(Iterable<NodeId> nodeIds);
  void toggleSelection(NodeId nodeId);
  void clearSelection();
  void selectAll({bool onlySelectable = true});
  void rotateSelection({required bool clockwise, int? timestampMs});
  void flipSelectionVertical({int? timestampMs});
  void flipSelectionHorizontal({int? timestampMs});
  void deleteSelection({int? timestampMs});
}

final class SceneControllerSelectionAccessAdapter
    implements SceneControllerSelectionAccess {
  const SceneControllerSelectionAccessAdapter({
    required this.runtime,
    required this.mutations,
  });

  final SceneControllerInteractionRuntime runtime;
  final SceneControllerSelectionMutations mutations;

  @override
  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {
    runtime.ensurePublicSideEffectAllowed(
      operation,
      allowAfterDispose: allowAfterDispose,
    );
  }

  @override
  void ensureExternalSelectionMutationAllowed(String operation) {
    runtime.ensureExternalSelectionMutationAllowed(operation);
  }

  @override
  void setSelection(Iterable<NodeId> nodeIds) {
    mutations.setSelection(nodeIds);
  }

  @override
  void toggleSelection(NodeId nodeId) {
    mutations.toggleSelection(nodeId);
  }

  @override
  void clearSelection() {
    mutations.clearSelection();
  }

  @override
  void selectAll({bool onlySelectable = true}) {
    mutations.selectAll(onlySelectable: onlySelectable);
  }

  @override
  void rotateSelection({required bool clockwise, int? timestampMs}) {
    mutations.rotateSelection(clockwise: clockwise, timestampMs: timestampMs);
  }

  @override
  void flipSelectionVertical({int? timestampMs}) {
    mutations.flipSelectionVertical(timestampMs: timestampMs);
  }

  @override
  void flipSelectionHorizontal({int? timestampMs}) {
    mutations.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  @override
  void deleteSelection({int? timestampMs}) {
    mutations.deleteSelection(timestampMs: timestampMs);
  }
}
