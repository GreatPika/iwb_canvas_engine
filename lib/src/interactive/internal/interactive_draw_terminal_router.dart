import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/interaction_types.dart';
import '../../core/pointer_input.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_action_emitter.dart';
import 'interactive_draw_eraser_engine.dart';
import 'interactive_draw_gesture_session.dart';
import 'interactive_draw_line_engine.dart';
import 'interactive_draw_stroke_engine.dart';

class InteractiveDrawTerminalRouter {
  const InteractiveDrawTerminalRouter({
    required this.gestureSession,
    required this.lineEngine,
    required this.strokeEngine,
    required this.eraserEngine,
    required this.emitAction,
  });

  final InteractiveDrawGestureSession gestureSession;
  final InteractiveDrawLineEngine lineEngine;
  final InteractiveDrawStrokeEngine strokeEngine;
  final InteractiveDrawEraserEngine eraserEngine;
  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;

  InteractiveDrawActionEmitter get _actionEmitter =>
      InteractiveDrawActionEmitter(emitAction: emitAction);

  void handleUp(
    PointerSample sample,
    Offset scenePoint, {
    required InteractiveDrawStyle style,
    required double dragStartSlop,
  }) {
    switch (style.drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        strokeEngine.commitOnUp(sample.timestampMs, scenePoint, style: style);
        break;
      case DrawTool.line:
        lineEngine.commitOnUp((
          timestampMs: sample.timestampMs,
          scenePoint: scenePoint,
          downScene: gestureSession.downScene,
          moved: gestureSession.moved,
          dragStartSlop: dragStartSlop,
        ), style: style);
        break;
      case DrawTool.eraser:
        final deletedIds = eraserEngine.commitOnUp(
          scenePoint,
          eraserThickness: style.eraserThickness,
        );
        if (deletedIds.isNotEmpty) {
          _actionEmitter.emitEraseCommit(
            nodeIds: deletedIds,
            timestampMs: sample.timestampMs,
            eraserThickness: style.eraserThickness,
          );
        }
        break;
    }

    gestureSession.clear();
    lineEngine.resetGestureState();
  }
}
