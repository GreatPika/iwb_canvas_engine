import '../snapshot.dart';
import 'snapshot_backing.dart';

NodeSnapshotBacking publicNodeSnapshotBackingOf(NodeSnapshot snapshot) {
  if (snapshot.runtimeType == ImageNodeSnapshot) {
    return _imageNodeSnapshotBacking(snapshot as ImageNodeSnapshot);
  }
  if (snapshot.runtimeType == TextNodeSnapshot) {
    return _textNodeSnapshotBacking(snapshot as TextNodeSnapshot);
  }
  if (snapshot.runtimeType == StrokeNodeSnapshot) {
    return _strokeNodeSnapshotBacking(snapshot as StrokeNodeSnapshot);
  }
  if (snapshot.runtimeType == LineNodeSnapshot) {
    return _lineNodeSnapshotBacking(snapshot as LineNodeSnapshot);
  }
  if (snapshot.runtimeType == RectNodeSnapshot) {
    return _rectNodeSnapshotBacking(snapshot as RectNodeSnapshot);
  }
  if (snapshot.runtimeType == PathNodeSnapshot) {
    return _pathNodeSnapshotBacking(snapshot as PathNodeSnapshot);
  }
  throw StateError('Unsupported NodeSnapshot subtype: ${snapshot.runtimeType}');
}

ImageNodeSnapshotBacking _imageNodeSnapshotBacking(ImageNodeSnapshot image) {
  return ImageNodeSnapshotBacking(
    id: image.id,
    instanceRevision: image.instanceRevision,
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

TextNodeSnapshotBacking _textNodeSnapshotBacking(TextNodeSnapshot text) {
  return TextNodeSnapshotBacking(
    id: text.id,
    instanceRevision: text.instanceRevision,
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

StrokeNodeSnapshotBacking _strokeNodeSnapshotBacking(
  StrokeNodeSnapshot stroke,
) {
  return StrokeNodeSnapshotBacking(
    id: stroke.id,
    instanceRevision: stroke.instanceRevision,
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

LineNodeSnapshotBacking _lineNodeSnapshotBacking(LineNodeSnapshot line) {
  return LineNodeSnapshotBacking(
    id: line.id,
    instanceRevision: line.instanceRevision,
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

RectNodeSnapshotBacking _rectNodeSnapshotBacking(RectNodeSnapshot rect) {
  return RectNodeSnapshotBacking(
    id: rect.id,
    instanceRevision: rect.instanceRevision,
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

PathNodeSnapshotBacking _pathNodeSnapshotBacking(PathNodeSnapshot path) {
  return PathNodeSnapshotBacking(
    id: path.id,
    instanceRevision: path.instanceRevision,
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
