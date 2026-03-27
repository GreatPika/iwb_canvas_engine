import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/interaction_types.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_line_engine.dart' show InteractiveDrawStyle;

class InteractiveDrawActionEmitter {
  const InteractiveDrawActionEmitter({required this.emitAction});

  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;

  void emitDrawCommit({
    required ActionType type,
    required NodeId nodeId,
    required int timestampMs,
    required DrawTool tool,
    required Color color,
    required double thickness,
  }) {
    emitAction(
      type,
      <NodeId>[nodeId],
      timestampMs,
      payload: <String, Object?>{
        'tool': tool.name,
        'color': color.toARGB32(),
        'thickness': thickness,
      },
    );
  }

  void emitLineCommit({
    required NodeId nodeId,
    required int timestampMs,
    required InteractiveDrawStyle style,
  }) {
    emitDrawCommit(
      type: ActionType.drawLine,
      nodeId: nodeId,
      timestampMs: timestampMs,
      tool: style.drawTool,
      color: style.drawColor,
      thickness: style.lineThickness,
    );
  }

  void emitStrokeCommit({
    required NodeId nodeId,
    required int timestampMs,
    required InteractiveDrawStyle style,
    required bool isHighlighter,
    required double thickness,
  }) {
    emitDrawCommit(
      type: isHighlighter ? ActionType.drawHighlighter : ActionType.drawStroke,
      nodeId: nodeId,
      timestampMs: timestampMs,
      tool: style.drawTool,
      color: style.drawColor,
      thickness: thickness,
    );
  }

  void emitEraseCommit({
    required List<NodeId> nodeIds,
    required int timestampMs,
    required double eraserThickness,
  }) {
    emitAction(
      ActionType.erase,
      nodeIds,
      timestampMs,
      payload: <String, Object?>{'eraserThickness': eraserThickness},
    );
  }
}
