import 'dart:ui';

import '../contracts/public/canvas_contract_limits.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';
import 'interaction_runtime_intents.dart';
import 'pointer_session_identity.dart';

final class DrawStrokeMachine {
  const DrawStrokeMachine();

  DrawStrokeStartDecision start({
    required CanvasDrawTool tool,
    required Offset startWorld,
    required CanvasDrawStyle style,
  }) {
    final strokeStyle = _strokeStyleFor(tool, style);
    if (strokeStyle == null) {
      return const DrawStrokeStartDecision.rejected();
    }

    return DrawStrokeStartDecision.admitted(
      stroke: PointerStrokeCapture(
        tool: tool,
        points: [startWorld],
        color: style.color,
        thickness: strokeStyle.thickness,
        opacity: strokeStyle.opacity,
      ),
    );
  }

  DrawStrokePreviewDecision preview({
    required PointerStrokeCapture stroke,
    required Offset currentWorld,
  }) {
    final points = _appendPoint(stroke.points, currentWorld);
    if (identical(points, stroke.points)) {
      return const DrawStrokePreviewDecision.noChange();
    }

    return DrawStrokePreviewDecision.changed(stroke: stroke.withPoints(points));
  }

  DrawStrokeTerminalDecision terminal({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required PointerStrokeCapture stroke,
    required Offset terminalWorld,
  }) {
    final points = _appendPoint(stroke.points, terminalWorld);

    return DrawStrokeTerminalDecision.commit(
      sessionId: sessionId,
      pointerToken: pointerToken,
      stroke: stroke.withPoints(points),
    );
  }

  List<Offset> _appendPoint(List<Offset> points, Offset point) {
    if (points.isNotEmpty && points.last == point) {
      return points;
    }
    if (points.length < canvasMaxStrokePointsPerElement) {
      return List.unmodifiable([...points, point]);
    }
    final capped = List<Offset>.of(points);
    capped[capped.length - 1] = point;

    return List.unmodifiable(capped);
  }
}

final class PointerStrokeCapture {
  PointerStrokeCapture({
    required this.tool,
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  final CanvasDrawTool tool;
  final List<Offset> points;
  final Color color;
  final double thickness;
  final double opacity;

  PointerStrokeCapture withPoints(Iterable<Offset> value) {
    return PointerStrokeCapture(
      tool: tool,
      points: value,
      color: color,
      thickness: thickness,
      opacity: opacity,
    );
  }

  CanvasPreviewState get preview {
    return switch (tool) {
      CanvasDrawTool.pencil => CanvasPencilStrokePreview(
        points: points,
        color: color,
        thickness: thickness,
        opacity: opacity,
      ),
      CanvasDrawTool.marker => CanvasMarkerStrokePreview(
        points: points,
        color: color,
        thickness: thickness,
        opacity: opacity,
      ),
      CanvasDrawTool.line || CanvasDrawTool.eraser => const CanvasNoPreview(),
    };
  }
}

final class DrawStrokeStartDecision {
  const DrawStrokeStartDecision.rejected() : admitted = false, stroke = null;

  const DrawStrokeStartDecision.admitted({required this.stroke})
    : admitted = true;

  final bool admitted;
  final PointerStrokeCapture? stroke;
}

final class DrawStrokePreviewDecision {
  const DrawStrokePreviewDecision.noChange() : changed = false, stroke = null;

  const DrawStrokePreviewDecision.changed({required this.stroke})
    : changed = true;

  final bool changed;
  final PointerStrokeCapture? stroke;
}

final class DrawStrokeTerminalDecision {
  DrawStrokeTerminalDecision.commit({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required PointerStrokeCapture stroke,
  }) : intent = DrawStrokeCommitIntent(
         sessionId: sessionId,
         pointerToken: pointerToken,
         tool: stroke.tool,
         points: stroke.points,
         color: stroke.color,
         thickness: stroke.thickness,
         opacity: stroke.opacity,
       );

  final DrawStrokeCommitIntent intent;
}

({double thickness, double opacity})? _strokeStyleFor(
  CanvasDrawTool tool,
  CanvasDrawStyle style,
) {
  return switch (tool) {
    CanvasDrawTool.pencil => (thickness: style.pencilThickness, opacity: 1.0),
    CanvasDrawTool.marker => (
      thickness: style.markerThickness,
      opacity: style.markerOpacity,
    ),
    CanvasDrawTool.line || CanvasDrawTool.eraser => null,
  };
}
