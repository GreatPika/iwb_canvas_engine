import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';

class InteractiveDrawCoordinatorCallbacks {
  const InteractiveDrawCoordinatorCallbacks({
    required this.onStateChanged,
    required this.emitAction,
    required this.commitDrawStroke,
    required this.commitDrawLineFromWorldSegment,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.commitEraseNodes,
  });

  final VoidCallback onStateChanged;
  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;
  final NodeId Function({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  })
  commitDrawStroke;
  final NodeId Function({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  })
  commitDrawLineFromWorldSegment;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final int Function(Iterable<NodeId> ids) commitEraseNodes;
}
