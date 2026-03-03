import 'dart:ui';

import 'numeric_clamp.dart';

/// Returns a centered local rectangle for a node size.
Rect centeredRectLocalBounds(Size size) {
  final safe = clampNonNegativeSizeFinite(size);
  return Rect.fromCenter(
    center: Offset.zero,
    width: safe.width,
    height: safe.height,
  );
}

/// Returns local bounds expanded by half stroke width when stroke is enabled.
Rect strokeAwareLocalBounds({
  required Rect baseBounds,
  required Color? strokeColor,
  required double strokeWidth,
}) {
  var bounds = sanitizeFiniteRect(baseBounds);
  final effectiveWidth = effectiveStrokeWidth(
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  );
  if (effectiveWidth > 0) {
    bounds = bounds.inflate(effectiveWidth / 2);
  }
  return sanitizeFiniteRect(bounds);
}

/// Returns centered local rectangle bounds with optional stroke inflation.
Rect strokeAwareCenteredRectLocalBounds({
  required Size size,
  required Color? strokeColor,
  required double strokeWidth,
}) {
  return strokeAwareLocalBounds(
    baseBounds: centeredRectLocalBounds(size),
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  );
}

/// Returns effective stroke width for bounds calculations.
double effectiveStrokeWidth({
  required Color? strokeColor,
  required double strokeWidth,
}) {
  if (strokeColor == null) {
    return 0;
  }
  return clampNonNegativeFinite(strokeWidth);
}

/// Returns [Rect.zero] for non-finite rectangles.
Rect sanitizeFiniteRect(Rect rect) {
  if (!isFiniteRect(rect)) {
    return Rect.zero;
  }
  return rect;
}

/// Returns true when all rectangle edges are finite.
bool isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}
