import '../core/nodes.dart';

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
