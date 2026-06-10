import 'dart:ui';

import '../contracts/public/canvas_preview.dart';
import 'captured_frame.dart';

enum OverlayPreviewPrimitiveKind {
  marquee,
  pencilStroke,
  markerStroke,
  pendingLineStart,
  linePreview,
  eraser,
}

sealed class OverlayPreviewPrimitive {
  const OverlayPreviewPrimitive({required this.kind});

  final OverlayPreviewPrimitiveKind kind;
}

final class MarqueeOverlayPrimitive extends OverlayPreviewPrimitive {
  const MarqueeOverlayPrimitive({
    required this.rect,
    required this.color,
    required this.strokeWidth,
    required this.fillOpacity,
  }) : super(kind: OverlayPreviewPrimitiveKind.marquee);

  final Rect rect;
  final Color color;
  final double strokeWidth;
  final double fillOpacity;
}

final class StrokeOverlayPrimitive extends OverlayPreviewPrimitive {
  StrokeOverlayPrimitive({
    required super.kind,
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  final List<Offset> points;
  final Color color;
  final double thickness;
  final double opacity;
}

final class PendingLineStartOverlayPrimitive extends OverlayPreviewPrimitive {
  const PendingLineStartOverlayPrimitive({
    required this.start,
    required this.timestampMs,
    required this.color,
    required this.thickness,
  }) : super(kind: OverlayPreviewPrimitiveKind.pendingLineStart);

  final Offset start;
  final int timestampMs;
  final Color color;
  final double thickness;
}

final class LineOverlayPrimitive extends OverlayPreviewPrimitive {
  const LineOverlayPrimitive({
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  }) : super(kind: OverlayPreviewPrimitiveKind.linePreview);

  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;
}

final class EraserOverlayPrimitive extends OverlayPreviewPrimitive {
  EraserOverlayPrimitive({
    required Iterable<Offset> corridor,
    required this.thickness,
  }) : corridor = List.unmodifiable(corridor),
       super(kind: OverlayPreviewPrimitiveKind.eraser);

  final List<Offset> corridor;
  final double thickness;
}

final class OverlayPreviewPlan {
  OverlayPreviewPlan({required Iterable<OverlayPreviewPrimitive> primitives})
    : primitives = List.unmodifiable(primitives);

  final List<OverlayPreviewPrimitive> primitives;
}

final class OverlayPreviewPlanner {
  const OverlayPreviewPlanner();

  OverlayPreviewPlan build(CapturedOverlayFrame frame) {
    final primitive = _primitiveFor(frame);

    return OverlayPreviewPlan(
      primitives: primitive == null ? const [] : [primitive],
    );
  }
}

OverlayPreviewPrimitive? _primitiveFor(CapturedOverlayFrame frame) {
  final preview = frame.overlayPreview;

  return switch (preview) {
    null || CanvasNoPreview() || CanvasSelectedMovePreview() => null,
    final CanvasMarqueePreview preview => _marqueePrimitive(frame, preview),
    final CanvasPencilStrokePreview preview => _strokePrimitive(
      preview,
      OverlayPreviewPrimitiveKind.pencilStroke,
    ),
    final CanvasMarkerStrokePreview preview => _strokePrimitive(
      preview,
      OverlayPreviewPrimitiveKind.markerStroke,
    ),
    final CanvasPendingLineStartPreview preview =>
      PendingLineStartOverlayPrimitive(
        start: preview.start,
        timestampMs: preview.timestampMs,
        color: preview.color,
        thickness: preview.thickness,
      ),
    final CanvasLinePreview preview => LineOverlayPrimitive(
      start: preview.start,
      end: preview.end,
      color: preview.color,
      thickness: preview.thickness,
    ),
    final CanvasEraserPreview preview => EraserOverlayPrimitive(
      corridor: preview.corridor,
      thickness: preview.thickness,
    ),
  };
}

MarqueeOverlayPrimitive _marqueePrimitive(
  CapturedOverlayFrame frame,
  CanvasMarqueePreview preview,
) {
  final style = frame.selectionStyle;

  return MarqueeOverlayPrimitive(
    rect: preview.rect,
    color: style.color,
    strokeWidth: style.strokeWidth,
    fillOpacity: style.marqueeFillOpacity,
  );
}

StrokeOverlayPrimitive _strokePrimitive(
  CanvasStrokePreview preview,
  OverlayPreviewPrimitiveKind kind,
) {
  return StrokeOverlayPrimitive(
    kind: kind,
    points: preview.points,
    color: preview.color,
    thickness: preview.thickness,
    opacity: preview.opacity,
  );
}
