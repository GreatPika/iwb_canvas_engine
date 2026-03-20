part of 'scene_node_boundary_mapping.dart';

SceneNode _imageNodeFromSpecViaBoundarySchema(
  ImageNodeSpec image, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSpec(
    _specCommonFromNodeSpec(image),
    fallbackId: fallbackId,
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
  return _imageNodeFromSchema(common: common, fields: fields);
}

SceneNode _textNodeFromSpecViaBoundarySchema(
  TextNodeSpec text, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSpec(
    _specCommonFromNodeSpec(text),
    fallbackId: fallbackId,
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.textSpecFieldsFromValidated((
    text: text.text,
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
  return _textNodeFromSpecSchema(common: common, fields: fields);
}

SceneNode _strokeNodeFromSpecViaBoundarySchema(
  StrokeNodeSpec stroke, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSpec(
    _specCommonFromNodeSpec(stroke),
    fallbackId: fallbackId,
    instanceRevision: instanceRevision,
  );
  final fields = NodeBoundarySchema.strokeSpecFieldsFromValidated((
    points: stroke.points,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
  return _strokeNodeFromSpecSchema(common: common, fields: fields);
}

SceneNode _lineNodeFromSpecViaBoundarySchema(
  LineNodeSpec line, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSpec(
    _specCommonFromNodeSpec(line),
    fallbackId: fallbackId,
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

SceneNode _rectNodeFromSpecViaBoundarySchema(
  RectNodeSpec rect, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSpec(
    _specCommonFromNodeSpec(rect),
    fallbackId: fallbackId,
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

SceneNode _pathNodeFromSpecViaBoundarySchema(
  PathNodeSpec path, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  final common = _runtimeCommonFromSpec(
    _specCommonFromNodeSpec(path),
    fallbackId: fallbackId,
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
