import '../contracts/public/canvas_element.dart';
import 'store_revision_delta.dart';

StoreRevisionDelta elementRevisionDelta({
  required CanvasElement before,
  required CanvasElement after,
}) {
  var delta = const StoreRevisionDelta();
  if (before.transform != after.transform ||
      before.isVisible != after.isVisible) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.opacity != after.opacity) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  if (before.hitPadding != after.hitPadding) {
    delta = delta.merge(const StoreRevisionDelta.elementBoundsOnly());
  }
  if (before.isSelectable != after.isSelectable ||
      before.isLocked != after.isLocked ||
      before.isDeletable != after.isDeletable ||
      before.isTransformable != after.isTransformable ||
      before.metadata != after.metadata) {
    delta = delta.merge(const StoreRevisionDelta.projectionOnly());
  }

  return delta.merge(_familyElementDelta(before, after));
}

StoreRevisionDelta _familyElementDelta(
  CanvasElement before,
  CanvasElement after,
) {
  return switch ((before, after)) {
    (final CanvasImageElement before, final CanvasImageElement after) =>
      _imageDelta(before, after),
    (final CanvasPathElement before, final CanvasPathElement after) =>
      _pathDelta(before, after),
    (final CanvasTextElement before, final CanvasTextElement after) =>
      _textDelta(before, after),
    (final CanvasStrokeElement before, final CanvasStrokeElement after) =>
      _strokeDelta(before, after),
    (final CanvasLineElement before, final CanvasLineElement after) =>
      _lineDelta(before, after),
    (final CanvasRectElement before, final CanvasRectElement after) =>
      _rectDelta(before, after),
    _ => const StoreRevisionDelta(),
  };
}

StoreRevisionDelta _imageDelta(
  CanvasImageElement before,
  CanvasImageElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.size != after.size) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.resourceId != after.resourceId ||
      before.naturalSize != after.naturalSize) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _pathDelta(
  CanvasPathElement before,
  CanvasPathElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.svgPathData != after.svgPathData ||
      before.strokeWidth != after.strokeWidth) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.fillColor != after.fillColor ||
      before.fillRule != after.fillRule) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  if (before.strokeColor != after.strokeColor) {
    delta = delta.merge(
      _strokePaintedBoundsChanged(
            before.strokeColor,
            before.strokeWidth,
            after.strokeColor,
            after.strokeWidth,
          )
          ? const StoreRevisionDelta.elementBounds()
          : const StoreRevisionDelta.elementVisual(),
    );
  }

  return delta;
}

StoreRevisionDelta _textDelta(
  CanvasTextElement before,
  CanvasTextElement after,
) {
  var delta = const StoreRevisionDelta();
  if (_anyChanged([
    before.text != after.text,
    before.fontSize != after.fontSize,
    before.align != after.align,
    before.textDirection != after.textDirection,
    before.isBold != after.isBold,
    before.isItalic != after.isItalic,
    before.fontFamily != after.fontFamily,
    before.maxWidth != after.maxWidth,
    before.lineHeight != after.lineHeight,
  ])) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color || before.isUnderline != after.isUnderline) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _strokeDelta(
  CanvasStrokeElement before,
  CanvasStrokeElement after,
) {
  var delta = const StoreRevisionDelta();
  if (!_sameList(before.points, after.points) ||
      before.thickness != after.thickness) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _lineDelta(
  CanvasLineElement before,
  CanvasLineElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.start != after.start ||
      before.end != after.end ||
      before.thickness != after.thickness) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _rectDelta(
  CanvasRectElement before,
  CanvasRectElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.size != after.size || before.strokeWidth != after.strokeWidth) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.fillColor != after.fillColor) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  if (before.strokeColor != after.strokeColor) {
    delta = delta.merge(
      _strokePaintedBoundsChanged(
            before.strokeColor,
            before.strokeWidth,
            after.strokeColor,
            after.strokeWidth,
          )
          ? const StoreRevisionDelta.elementBounds()
          : const StoreRevisionDelta.elementVisual(),
    );
  }

  return delta;
}

bool _strokePaintedBoundsChanged(
  Object? beforeColor,
  double beforeWidth,
  Object? afterColor,
  double afterWidth,
) {
  return _hasPaintedStroke(beforeColor, beforeWidth) !=
      _hasPaintedStroke(afterColor, afterWidth);
}

bool _hasPaintedStroke(Object? color, double width) {
  return color != null && width > 0;
}

bool _anyChanged(Iterable<bool> changes) {
  return changes.any((changed) => changed);
}

bool _sameList<T>(List<T> left, List<T> right) {
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
