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
  return ImageNodeSpec._internal(
    id: id,
    imageId: imageId,
    size: size,
    naturalSize: naturalSize,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
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
  return TextNodeSpec._internal(
    id: id,
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
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
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
  return StrokeNodeSpec._internal(
    id: id,
    points: points,
    thickness: thickness,
    color: color,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
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
  return LineNodeSpec._internal(
    id: id,
    start: start,
    end: end,
    thickness: thickness,
    color: color,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
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
  return RectNodeSpec._internal(
    id: id,
    size: size,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
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
  return PathNodeSpec._internal(
    id: id,
    svgPathData: svgPathData,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    fillRule: fillRule,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}
