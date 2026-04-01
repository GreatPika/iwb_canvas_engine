import '../node_patch.dart';
import 'node_patch_backing.dart';

NodePatchBacking publicNodePatchBackingOf(
  NodePatch patch,
  CommonNodePatchBacking common,
) {
  if (patch.runtimeType == ImageNodePatch) {
    return _imageNodePatchBacking(patch as ImageNodePatch, common);
  }
  if (patch.runtimeType == TextNodePatch) {
    return _textNodePatchBacking(patch as TextNodePatch, common);
  }
  if (patch.runtimeType == StrokeNodePatch) {
    return _strokeNodePatchBacking(patch as StrokeNodePatch, common);
  }
  if (patch.runtimeType == LineNodePatch) {
    return _lineNodePatchBacking(patch as LineNodePatch, common);
  }
  if (patch.runtimeType == RectNodePatch) {
    return _rectNodePatchBacking(patch as RectNodePatch, common);
  }
  if (patch.runtimeType == PathNodePatch) {
    return _pathNodePatchBacking(patch as PathNodePatch, common);
  }
  throw StateError('Unsupported NodePatch subtype: ${patch.runtimeType}');
}

ImageNodePatchBacking _imageNodePatchBacking(
  ImageNodePatch image,
  CommonNodePatchBacking common,
) {
  return ImageNodePatchBacking(
    id: image.id,
    common: common,
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  );
}

TextNodePatchBacking _textNodePatchBacking(
  TextNodePatch text,
  CommonNodePatchBacking common,
) {
  return TextNodePatchBacking(
    id: text.id,
    common: common,
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
  );
}

StrokeNodePatchBacking _strokeNodePatchBacking(
  StrokeNodePatch stroke,
  CommonNodePatchBacking common,
) {
  return StrokeNodePatchBacking(
    id: stroke.id,
    common: common,
    points: stroke.points,
    thickness: stroke.thickness,
    color: stroke.color,
  );
}

LineNodePatchBacking _lineNodePatchBacking(
  LineNodePatch line,
  CommonNodePatchBacking common,
) {
  return LineNodePatchBacking(
    id: line.id,
    common: common,
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  );
}

RectNodePatchBacking _rectNodePatchBacking(
  RectNodePatch rect,
  CommonNodePatchBacking common,
) {
  return RectNodePatchBacking(
    id: rect.id,
    common: common,
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  );
}

PathNodePatchBacking _pathNodePatchBacking(
  PathNodePatch path,
  CommonNodePatchBacking common,
) {
  return PathNodePatchBacking(
    id: path.id,
    common: common,
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  );
}
