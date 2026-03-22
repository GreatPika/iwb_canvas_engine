import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';

typedef MoveCommitSelectionResult = ({
  Offset appliedDelta,
  List<NodeId> movedIds,
});

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
  });

  final VoidCallback onStateChanged;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
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
