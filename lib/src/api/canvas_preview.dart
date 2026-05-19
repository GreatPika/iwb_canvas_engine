import 'dart:ui';

enum CanvasPreviewKind {
  none,
  marquee,
  selectedMove,
  pencilStroke,
  markerStroke,
  pendingLineStart,
  linePreview,
  eraser,
}

sealed class CanvasPreviewState {
  const CanvasPreviewState();
  const factory CanvasPreviewState.none() = CanvasNoPreview;
  const factory CanvasPreviewState.marquee({required Rect rect}) =
      CanvasMarqueePreview;
  const factory CanvasPreviewState.selectedMove({required Offset delta}) =
      CanvasSelectedMovePreview;
  factory CanvasPreviewState.pencilStroke({
    required Iterable<Offset> points,
    required Color color,
    required double thickness,
    required double opacity,
  }) = CanvasPencilStrokePreview;
  factory CanvasPreviewState.markerStroke({
    required Iterable<Offset> points,
    required Color color,
    required double thickness,
    required double opacity,
  }) = CanvasMarkerStrokePreview;
  const factory CanvasPreviewState.pendingLineStart({
    required Offset start,
    required int timestampMs,
    required Color color,
    required double thickness,
  }) = CanvasPendingLineStartPreview;
  const factory CanvasPreviewState.linePreview({
    required Offset start,
    required Offset end,
    required Color color,
    required double thickness,
  }) = CanvasLinePreview;
  factory CanvasPreviewState.eraser({
    required Iterable<Offset> corridor,
    required double thickness,
  }) = CanvasEraserPreview;

  CanvasPreviewKind get kind;
}

final class CanvasNoPreview extends CanvasPreviewState {
  const CanvasNoPreview();
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.none;
}

final class CanvasMarqueePreview extends CanvasPreviewState {
  const CanvasMarqueePreview({required this.rect});
  final Rect rect;
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.marquee;
}

final class CanvasSelectedMovePreview extends CanvasPreviewState {
  const CanvasSelectedMovePreview({required this.delta});
  final Offset delta;
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.selectedMove;
}

sealed class CanvasStrokePreview extends CanvasPreviewState {
  const CanvasStrokePreview();
  List<Offset> get points;
  Color get color;
  double get thickness;
  double get opacity;
}

final class CanvasPencilStrokePreview extends CanvasStrokePreview {
  CanvasPencilStrokePreview({
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  @override
  final List<Offset> points;
  @override
  final Color color;
  @override
  final double thickness;
  @override
  final double opacity;
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.pencilStroke;
}

final class CanvasMarkerStrokePreview extends CanvasStrokePreview {
  CanvasMarkerStrokePreview({
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  @override
  final List<Offset> points;
  @override
  final Color color;
  @override
  final double thickness;
  @override
  final double opacity;
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.markerStroke;
}

final class CanvasPendingLineStartPreview extends CanvasPreviewState {
  const CanvasPendingLineStartPreview({
    required this.start,
    required this.timestampMs,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final int timestampMs;
  final Color color;
  final double thickness;
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.pendingLineStart;
}

final class CanvasLinePreview extends CanvasPreviewState {
  const CanvasLinePreview({
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.linePreview;
}

final class CanvasEraserPreview extends CanvasPreviewState {
  CanvasEraserPreview({
    required Iterable<Offset> corridor,
    required this.thickness,
  }) : corridor = List.unmodifiable(corridor);

  final List<Offset> corridor;
  final double thickness;
  @override
  CanvasPreviewKind get kind => CanvasPreviewKind.eraser;
}
