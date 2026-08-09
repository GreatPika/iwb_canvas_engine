import '../contracts/public/canvas_element.dart';

bool sameCanvasElementSnapshot(CanvasElement left, CanvasElement right) {
  if (!_sameCanvasElementCommon(left, right)) {
    return false;
  }

  return switch ((left, right)) {
    (final CanvasImageElement left, final CanvasImageElement right) =>
      _sameImageElement(left, right),
    (final CanvasVectorElement left, final CanvasVectorElement right) =>
      _sameVectorElement(left, right),
    (final CanvasPathElement left, final CanvasPathElement right) =>
      _samePathElement(left, right),
    (final CanvasTextElement left, final CanvasTextElement right) =>
      _sameTextElement(left, right),
    (final CanvasStrokeElement left, final CanvasStrokeElement right) =>
      _sameStrokeElement(left, right),
    (final CanvasLineElement left, final CanvasLineElement right) =>
      _sameLineElement(left, right),
    (final CanvasRectElement left, final CanvasRectElement right) =>
      _sameRectElement(left, right),
    _ => false,
  };
}

bool _sameCanvasElementCommon(CanvasElement left, CanvasElement right) {
  return [
    left.id == right.id,
    left.kind == right.kind,
    left.revision == right.revision,
    left.transform == right.transform,
    left.opacity == right.opacity,
    left.hitPadding == right.hitPadding,
    left.isVisible == right.isVisible,
    left.isSelectable == right.isSelectable,
    left.isLocked == right.isLocked,
    left.isDeletable == right.isDeletable,
    left.isTransformable == right.isTransformable,
    left.metadata == right.metadata,
  ].every((same) => same);
}

bool _sameImageElement(CanvasImageElement left, CanvasImageElement right) {
  return left.resourceId == right.resourceId &&
      left.size == right.size &&
      left.naturalSize == right.naturalSize;
}

bool _sameVectorElement(CanvasVectorElement left, CanvasVectorElement right) {
  return left.resourceId == right.resourceId &&
      left.size == right.size &&
      left.naturalSize == right.naturalSize;
}

bool _samePathElement(CanvasPathElement left, CanvasPathElement right) {
  return [
    left.svgPathData == right.svgPathData,
    left.fillColor == right.fillColor,
    left.strokeColor == right.strokeColor,
    left.strokeWidth == right.strokeWidth,
    left.fillRule == right.fillRule,
  ].every((same) => same);
}

bool _sameTextElement(CanvasTextElement left, CanvasTextElement right) {
  return [
    left.text == right.text,
    left.color == right.color,
    left.textDirection == right.textDirection,
    left.fontSize == right.fontSize,
    left.align == right.align,
    left.isBold == right.isBold,
    left.isItalic == right.isItalic,
    left.isUnderline == right.isUnderline,
    left.fontFamily == right.fontFamily,
    left.maxWidth == right.maxWidth,
    left.lineHeight == right.lineHeight,
  ].every((same) => same);
}

bool _sameStrokeElement(CanvasStrokeElement left, CanvasStrokeElement right) {
  return _sameList(left.points, right.points) &&
      left.thickness == right.thickness &&
      left.color == right.color;
}

bool _sameLineElement(CanvasLineElement left, CanvasLineElement right) {
  return [
    left.start == right.start,
    left.end == right.end,
    left.thickness == right.thickness,
    left.color == right.color,
  ].every((same) => same);
}

bool _sameRectElement(CanvasRectElement left, CanvasRectElement right) {
  return [
    left.size == right.size,
    left.fillColor == right.fillColor,
    left.strokeColor == right.strokeColor,
    left.strokeWidth == right.strokeWidth,
  ].every((same) => same);
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
