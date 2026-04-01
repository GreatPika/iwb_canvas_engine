import '../node_spec.dart';
import 'node_spec_backing.dart';

NodeSpecBacking publicNodeSpecBackingOf(NodeSpec spec) {
  if (spec.runtimeType == ImageNodeSpec) {
    return _imageNodeSpecBacking(spec as ImageNodeSpec);
  }
  if (spec.runtimeType == TextNodeSpec) {
    return _textNodeSpecBacking(spec as TextNodeSpec);
  }
  if (spec.runtimeType == StrokeNodeSpec) {
    return _strokeNodeSpecBacking(spec as StrokeNodeSpec);
  }
  if (spec.runtimeType == LineNodeSpec) {
    return _lineNodeSpecBacking(spec as LineNodeSpec);
  }
  if (spec.runtimeType == RectNodeSpec) {
    return _rectNodeSpecBacking(spec as RectNodeSpec);
  }
  if (spec.runtimeType == PathNodeSpec) {
    return _pathNodeSpecBacking(spec as PathNodeSpec);
  }
  throw StateError('Unsupported NodeSpec subtype: ${spec.runtimeType}');
}

ImageNodeSpecBacking _imageNodeSpecBacking(ImageNodeSpec image) {
  return ImageNodeSpecBacking(
    id: image.id,
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
    transform: image.transform,
    opacity: image.opacity,
    hitPadding: image.hitPadding,
    isVisible: image.isVisible,
    isSelectable: image.isSelectable,
    isLocked: image.isLocked,
    isDeletable: image.isDeletable,
    isTransformable: image.isTransformable,
  );
}

TextNodeSpecBacking _textNodeSpecBacking(TextNodeSpec text) {
  return TextNodeSpecBacking(
    id: text.id,
    text: text.text,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    textDirection: text.textDirection,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
    transform: text.transform,
    opacity: text.opacity,
    hitPadding: text.hitPadding,
    isVisible: text.isVisible,
    isSelectable: text.isSelectable,
    isLocked: text.isLocked,
    isDeletable: text.isDeletable,
    isTransformable: text.isTransformable,
  );
}

StrokeNodeSpecBacking _strokeNodeSpecBacking(StrokeNodeSpec stroke) {
  return StrokeNodeSpecBacking(
    id: stroke.id,
    points: stroke.points,
    thickness: stroke.thickness,
    color: stroke.color,
    transform: stroke.transform,
    opacity: stroke.opacity,
    hitPadding: stroke.hitPadding,
    isVisible: stroke.isVisible,
    isSelectable: stroke.isSelectable,
    isLocked: stroke.isLocked,
    isDeletable: stroke.isDeletable,
    isTransformable: stroke.isTransformable,
  );
}

LineNodeSpecBacking _lineNodeSpecBacking(LineNodeSpec line) {
  return LineNodeSpecBacking(
    id: line.id,
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
    transform: line.transform,
    opacity: line.opacity,
    hitPadding: line.hitPadding,
    isVisible: line.isVisible,
    isSelectable: line.isSelectable,
    isLocked: line.isLocked,
    isDeletable: line.isDeletable,
    isTransformable: line.isTransformable,
  );
}

RectNodeSpecBacking _rectNodeSpecBacking(RectNodeSpec rect) {
  return RectNodeSpecBacking(
    id: rect.id,
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
    transform: rect.transform,
    opacity: rect.opacity,
    hitPadding: rect.hitPadding,
    isVisible: rect.isVisible,
    isSelectable: rect.isSelectable,
    isLocked: rect.isLocked,
    isDeletable: rect.isDeletable,
    isTransformable: rect.isTransformable,
  );
}

PathNodeSpecBacking _pathNodeSpecBacking(PathNodeSpec path) {
  return PathNodeSpecBacking(
    id: path.id,
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
    transform: path.transform,
    opacity: path.opacity,
    hitPadding: path.hitPadding,
    isVisible: path.isVisible,
    isSelectable: path.isSelectable,
    isLocked: path.isLocked,
    isDeletable: path.isDeletable,
    isTransformable: path.isTransformable,
  );
}
