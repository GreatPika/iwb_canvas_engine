import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';

typedef MoveCommitSelectionResult = ({
  Offset appliedDelta,
  List<NodeId> movedIds,
});

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
  });

  final VoidCallback onPublicStateChanged;
  final VoidCallback onSceneStateChanged;
  final VoidCallback onOverlayStateChanged;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final void Function(Iterable<NodeId> nodeIds) writeSelectionReplace;
  final void Function() writeSelectionClear;
  final MoveCommitSelectionResult Function(Offset proposedDelta)
  commitMoveSelection;
  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;
}
