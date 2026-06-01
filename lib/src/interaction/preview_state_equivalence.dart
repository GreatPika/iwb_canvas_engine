import 'dart:ui';

import '../contracts/public/canvas_preview.dart';

bool canvasPreviewStatesEqual(
  CanvasPreviewState left,
  CanvasPreviewState right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.kind != right.kind) {
    return false;
  }

  return switch (left) {
    CanvasNoPreview() => _noPreviewsEqual(right),
    CanvasMarqueePreview() => _marqueePreviewsEqual(left, right),
    CanvasSelectedMovePreview() => _selectedMovePreviewsEqual(left, right),
    CanvasPencilStrokePreview() => _pencilStrokesEqual(left, right),
    CanvasMarkerStrokePreview() => _markerStrokesEqual(left, right),
    CanvasPendingLineStartPreview() => _pendingLineStartsEqual(left, right),
    CanvasLinePreview() => _linePreviewsEqual(left, right),
    CanvasEraserPreview() => _eraserPreviewsEqual(left, right),
  };
}

bool _noPreviewsEqual(CanvasPreviewState right) {
  return right is CanvasNoPreview;
}

bool _marqueePreviewsEqual(
  CanvasMarqueePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasMarqueePreview && left.rect == right.rect;
}

bool _selectedMovePreviewsEqual(
  CanvasSelectedMovePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasSelectedMovePreview && left.delta == right.delta;
}

bool _pencilStrokesEqual(
  CanvasPencilStrokePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasPencilStrokePreview && _strokesEqual(left, right);
}

bool _markerStrokesEqual(
  CanvasMarkerStrokePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasMarkerStrokePreview && _strokesEqual(left, right);
}

bool _strokesEqual(CanvasStrokePreview left, CanvasStrokePreview right) {
  return left.color == right.color &&
      left.thickness == right.thickness &&
      left.opacity == right.opacity &&
      _offsetListsEqual(left.points, right.points);
}

bool _pendingLineStartsEqual(
  CanvasPendingLineStartPreview left,
  CanvasPreviewState right,
) {
  if (right is! CanvasPendingLineStartPreview) {
    return false;
  }

  return left.start == right.start &&
      left.timestampMs == right.timestampMs &&
      left.color == right.color &&
      left.thickness == right.thickness;
}

bool _linePreviewsEqual(CanvasLinePreview left, CanvasPreviewState right) {
  if (right is! CanvasLinePreview) {
    return false;
  }

  return left.start == right.start &&
      left.end == right.end &&
      left.color == right.color &&
      left.thickness == right.thickness;
}

bool _eraserPreviewsEqual(CanvasEraserPreview left, CanvasPreviewState right) {
  if (right is! CanvasEraserPreview) {
    return false;
  }

  return left.thickness == right.thickness &&
      _offsetListsEqual(left.corridor, right.corridor);
}

bool _offsetListsEqual(List<Offset> left, List<Offset> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}
