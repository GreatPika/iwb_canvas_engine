import 'dart:ui';

import '../../core/interaction_types.dart';
import '../../core/scene_spatial_index.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_style.dart';
import 'interactive_move_callbacks.dart';

class InteractiveRuntimeCallbacks {
  const InteractiveRuntimeCallbacks({
    required this.schedulePublicNotify,
    required this.scheduleSceneNotify,
    required this.scheduleOverlayNotify,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readMode,
    required this.readDragStartSlop,
    required this.readDrawStyle,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.commitDrawStroke,
    required this.commitDrawLineFromWorldSegment,
    required this.commitEraseNodes,
  });

  final VoidCallback schedulePublicNotify;
  final VoidCallback scheduleSceneNotify;
  final VoidCallback scheduleOverlayNotify;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final CanvasMode Function() readMode;
  final double Function() readDragStartSlop;
  final InteractiveDrawStyle Function() readDrawStyle;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
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
