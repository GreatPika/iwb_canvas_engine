import 'dart:ui';

import 'interactive_move_callbacks.dart';
import 'scene_controller_mutation_boundary.dart';

final class InteractiveSelectionActions {
  const InteractiveSelectionActions({required this.mutations});

  final SceneControllerMutationBoundary mutations;

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    mutations.rotateSelection(clockwise: clockwise, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    mutations.flipSelectionVertical(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    mutations.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    mutations.deleteSelection(timestampMs: timestampMs);
  }

  void clearScene({int? timestampMs}) {
    mutations.clearScene(timestampMs: timestampMs);
  }

  MoveCommitSelectionResult commitMoveSelection(Offset proposedDelta) {
    return mutations.commitMoveSelection(proposedDelta);
  }
}
