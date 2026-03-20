part of '../node_spec.dart';

@internal
ImageNodeSpec imageNodeSpecFromValidated({
  NodeId? id,
  required String imageId,
  required Size size,
  Size? naturalSize,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  final common = NodeBoundarySchema.specCommonFromValidated((
    id: id,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  ));
  final fields = NodeBoundarySchema.imageFieldsFromValidated((
    imageId: imageId,
    size: size,
    naturalSize: naturalSize,
  ));
  return ImageNodeSpec._internal(
    id: common.id,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

@internal
TextNodeSpec textNodeSpecFromValidated({
  NodeId? id,
  required String text,
  double fontSize = 24,
  required Color color,
  TextAlign align = TextAlign.left,
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  final common = NodeBoundarySchema.specCommonFromValidated((
    id: id,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  ));
  final fields = NodeBoundarySchema.textSpecFieldsFromValidated((
    text: text,
    fontSize: fontSize,
    color: color,
    align: align,
    isBold: isBold,
    isItalic: isItalic,
    isUnderline: isUnderline,
    fontFamily: fontFamily,
    maxWidth: maxWidth,
    lineHeight: lineHeight,
  ));
  return TextNodeSpec._internal(
    id: common.id,
    text: fields.text,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

@internal
StrokeNodeSpec strokeNodeSpecFromValidated({
  NodeId? id,
  required List<Offset> points,
  required double thickness,
  required Color color,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  final common = NodeBoundarySchema.specCommonFromValidated((
    id: id,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  ));
  final fields = NodeBoundarySchema.strokeSpecFieldsFromValidated((
    points: points,
    thickness: thickness,
    color: color,
  ));
  return StrokeNodeSpec._internal(
    id: common.id,
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

@internal
LineNodeSpec lineNodeSpecFromValidated({
  NodeId? id,
  required Offset start,
  required Offset end,
  required double thickness,
  required Color color,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  final common = NodeBoundarySchema.specCommonFromValidated((
    id: id,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  ));
  final fields = NodeBoundarySchema.lineFieldsFromValidated((
    start: start,
    end: end,
    thickness: thickness,
    color: color,
  ));
  return LineNodeSpec._internal(
    id: common.id,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

@internal
RectNodeSpec rectNodeSpecFromValidated({
  NodeId? id,
  required Size size,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth = 1,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  final common = NodeBoundarySchema.specCommonFromValidated((
    id: id,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  ));
  final fields = NodeBoundarySchema.rectFieldsFromValidated((
    size: size,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  ));
  return RectNodeSpec._internal(
    id: common.id,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

@internal
PathNodeSpec pathNodeSpecFromValidated({
  NodeId? id,
  required String svgPathData,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth = 1,
  PathFillRule fillRule = PathFillRule.nonZero,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  final common = NodeBoundarySchema.specCommonFromValidated((
    id: id,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  ));
  final fields = NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: svgPathData,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    fillRule: fillRule,
  ));
  return PathNodeSpec._internal(
    id: common.id,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}
