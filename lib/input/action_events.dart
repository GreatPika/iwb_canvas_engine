import 'dart:ui';

import '../core/nodes.dart';

/// Discrete actions emitted by [SceneController] for app-level undo/redo.
enum ActionType {
  move,
  selectMarquee,
  rotate,
  flip,
  delete,
  clear,
  drawStroke,
  drawHighlighter,
  drawLine,
  erase,
}

/// A committed action with stable [actionId] and affected [nodeIds].
class ActionCommitted {
  const ActionCommitted({
    required this.actionId,
    required this.type,
    required this.nodeIds,
    required this.timestampMs,
    this.payload,
  });

  final String actionId;
  final ActionType type;
  final List<NodeId> nodeIds;
  final int timestampMs;
  final Map<String, Object?>? payload;
}

/// Request from the engine to edit a [TextNode] at [position].
class EditTextRequested {
  const EditTextRequested({
    required this.nodeId,
    required this.timestampMs,
    required this.position,
  });

  final NodeId nodeId;
  final int timestampMs;
  final Offset position;
}
