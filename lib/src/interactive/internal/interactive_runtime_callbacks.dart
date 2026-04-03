import 'dart:ui';

import '../../core/interaction_types.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_style.dart';
import 'interactive_move_callbacks.dart';

class InteractiveRuntimeCallbacks {
  const InteractiveRuntimeCallbacks({
    required this.scheduleNotify,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readMode,
    required this.readDragStartSlop,
    required this.readDrawStyle,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.commitDrawStroke,
    required this.commitDrawLineFromWorldSegment,
    required this.commitEraseNodes,
  });

  final VoidCallback scheduleNotify;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final CanvasMode Function() readMode;
  final double Function() readDragStartSlop;
  final InteractiveDrawStyle Function() readDrawStyle;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final void Function(Iterable<NodeId> nodeIds) writeSelectionReplace;
  final void Function() writeSelectionClear;
  final MoveCommitSelectionResult Function(Offset proposedDelta)
  commitMoveSelection;
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
  final int Function(Iterable<NodeId> ids) commitEraseNodes;
}
