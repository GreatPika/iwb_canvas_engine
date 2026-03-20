part of 'scene_node_boundary_mapping.dart';

SceneNode _imageNodeFromSnapshotViaBoundarySchema(
  ImageNodeSnapshot image, {
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSnapshot(
    _snapshotCommonFromNodeSnapshot(image),
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
  return _imageNodeFromSchema(common: common, fields: fields);
}

SceneNode _textNodeFromSnapshotViaBoundarySchema(
  TextNodeSnapshot text, {
  required int instanceRevision,
  required TextNodeSnapshotSizePolicy textSizePolicy,
}) {
  final common = _runtimeCommonFromSnapshot(
    _snapshotCommonFromNodeSnapshot(text),
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.textSnapshotFieldsFromValidated((
    text: text.text,
    size: text.size,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
  return _textNodeFromSnapshotSchema(
    common: common,
    fields: fields,
    textSizePolicy: textSizePolicy,
  );
}

SceneNode _strokeNodeFromSnapshotViaBoundarySchema(
  StrokeNodeSnapshot stroke, {
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSnapshot(
    _snapshotCommonFromNodeSnapshot(stroke),
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: stroke.points,
    pointsRevision: stroke.pointsRevision,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
  return _strokeNodeFromSnapshotSchema(common: common, fields: fields);
}

SceneNode _lineNodeFromSnapshotViaBoundarySchema(
  LineNodeSnapshot line, {
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSnapshot(
    _snapshotCommonFromNodeSnapshot(line),
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.lineFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
  return _lineNodeFromSchema(common: common, fields: fields);
}

SceneNode _rectNodeFromSnapshotViaBoundarySchema(
  RectNodeSnapshot rect, {
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSnapshot(
    _snapshotCommonFromNodeSnapshot(rect),
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.rectFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
  return _rectNodeFromSchema(common: common, fields: fields);
}

SceneNode _pathNodeFromSnapshotViaBoundarySchema(
  PathNodeSnapshot path, {
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSnapshot(
    _snapshotCommonFromNodeSnapshot(path),
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
  return _pathNodeFromSchema(common: common, fields: fields);
}
