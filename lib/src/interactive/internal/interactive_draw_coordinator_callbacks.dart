import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';

class InteractiveDrawCoordinatorCallbacks {
  const InteractiveDrawCoordinatorCallbacks({
    required this.onStateChanged,
    required this.emitAction,
    required this.writeDrawStroke,
    required this.writeDrawLineFromWorldSegment,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeEraseNodes,
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
  writeDrawStroke;
  final NodeId Function({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  })
  writeDrawLineFromWorldSegment;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final int Function(Iterable<NodeId> ids) writeEraseNodes;
}
