import 'dart:ui';

import '../ids.dart';
import '../owned_collections.dart';
import '../path_fill_rule.dart';
import '../transform2d.dart';
import 'node_boundary_schema.dart';

sealed class NodeSpecBacking {
  const NodeSpecBacking({
    this.id,
    this.transform = Transform2D.identity,
    this.opacity = 1,
    this.hitPadding = 0,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
  });

  final NodeId? id;
  final Transform2D transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
}

final class ImageNodeSpecBacking extends NodeSpecBacking {
  const ImageNodeSpecBacking({
    super.id,
    required this.imageId,
    required this.size,
    this.naturalSize,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final String imageId;
  final Size size;
  final Size? naturalSize;
}

final class TextNodeSpecBacking extends NodeSpecBacking {
  const TextNodeSpecBacking({
    super.id,
    required this.text,
    this.fontSize = 24,
    required this.color,
    this.align = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection textDirection;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}

final class StrokeNodeSpecBacking extends NodeSpecBacking {
  StrokeNodeSpecBacking({
    super.id,
    required Iterable<Offset> points,
    required this.thickness,
    required this.color,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : points = OwnedList<Offset>.of(points);

  final OwnedList<Offset> points;
  final double thickness;
  final Color color;
}

final class LineNodeSpecBacking extends NodeSpecBacking {
  const LineNodeSpecBacking({
    super.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
}

final class RectNodeSpecBacking extends NodeSpecBacking {
  const RectNodeSpecBacking({
    super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

final class PathNodeSpecBacking extends NodeSpecBacking {
  const PathNodeSpecBacking({
    super.id,
    required this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    this.fillRule = PathFillRule.nonZero,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final PathFillRule fillRule;
}

ImageNodeSpecBacking imageNodeSpecBackingFromValidated({
  NodeSpecCommonSchemaFields? common,
  required ImageNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = imageNodeSchemaFieldsFromValidated(fields);
  return ImageNodeSpecBacking(
    id: resolvedCommon.id,
    imageId: resolvedFields.imageId,
    size: resolvedFields.size,
    naturalSize: resolvedFields.naturalSize,
    transform: resolvedCommon.transform,
    opacity: resolvedCommon.opacity,
    hitPadding: resolvedCommon.hitPadding,
    isVisible: resolvedCommon.isVisible,
    isSelectable: resolvedCommon.isSelectable,
    isLocked: resolvedCommon.isLocked,
    isDeletable: resolvedCommon.isDeletable,
    isTransformable: resolvedCommon.isTransformable,
  );
}

TextNodeSpecBacking textNodeSpecBackingFromValidated({
  NodeSpecCommonSchemaFields? common,
  required TextNodeSpecSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = textNodeSpecSchemaFieldsFromValidated(fields);
  return TextNodeSpecBacking(
    id: resolvedCommon.id,
    text: resolvedFields.text,
    fontSize: resolvedFields.fontSize,
    color: resolvedFields.color,
    align: resolvedFields.align,
    textDirection: resolvedFields.textDirection,
    isBold: resolvedFields.isBold,
    isItalic: resolvedFields.isItalic,
    isUnderline: resolvedFields.isUnderline,
    fontFamily: resolvedFields.fontFamily,
    maxWidth: resolvedFields.maxWidth,
    lineHeight: resolvedFields.lineHeight,
    transform: resolvedCommon.transform,
    opacity: resolvedCommon.opacity,
    hitPadding: resolvedCommon.hitPadding,
    isVisible: resolvedCommon.isVisible,
    isSelectable: resolvedCommon.isSelectable,
    isLocked: resolvedCommon.isLocked,
    isDeletable: resolvedCommon.isDeletable,
    isTransformable: resolvedCommon.isTransformable,
  );
}

StrokeNodeSpecBacking strokeNodeSpecBackingFromValidated({
  NodeSpecCommonSchemaFields? common,
  required StrokeNodeSpecSchemaInput fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = strokeNodeSpecSchemaFieldsFromValidated(fields);
  return StrokeNodeSpecBacking(
    id: resolvedCommon.id,
    points: resolvedFields.points,
    thickness: resolvedFields.thickness,
    color: resolvedFields.color,
    transform: resolvedCommon.transform,
    opacity: resolvedCommon.opacity,
    hitPadding: resolvedCommon.hitPadding,
    isVisible: resolvedCommon.isVisible,
    isSelectable: resolvedCommon.isSelectable,
    isLocked: resolvedCommon.isLocked,
    isDeletable: resolvedCommon.isDeletable,
    isTransformable: resolvedCommon.isTransformable,
  );
}

LineNodeSpecBacking lineNodeSpecBackingFromValidated({
  NodeSpecCommonSchemaFields? common,
  required LineNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = lineNodeSchemaFieldsFromValidated(fields);
  return LineNodeSpecBacking(
    id: resolvedCommon.id,
    start: resolvedFields.start,
    end: resolvedFields.end,
    thickness: resolvedFields.thickness,
    color: resolvedFields.color,
    transform: resolvedCommon.transform,
    opacity: resolvedCommon.opacity,
    hitPadding: resolvedCommon.hitPadding,
    isVisible: resolvedCommon.isVisible,
    isSelectable: resolvedCommon.isSelectable,
    isLocked: resolvedCommon.isLocked,
    isDeletable: resolvedCommon.isDeletable,
    isTransformable: resolvedCommon.isTransformable,
  );
}

RectNodeSpecBacking rectNodeSpecBackingFromValidated({
  NodeSpecCommonSchemaFields? common,
  required RectNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = rectNodeSchemaFieldsFromValidated(fields);
  return RectNodeSpecBacking(
    id: resolvedCommon.id,
    size: resolvedFields.size,
    fillColor: resolvedFields.fillColor,
    strokeColor: resolvedFields.strokeColor,
    strokeWidth: resolvedFields.strokeWidth,
    transform: resolvedCommon.transform,
    opacity: resolvedCommon.opacity,
    hitPadding: resolvedCommon.hitPadding,
    isVisible: resolvedCommon.isVisible,
    isSelectable: resolvedCommon.isSelectable,
    isLocked: resolvedCommon.isLocked,
    isDeletable: resolvedCommon.isDeletable,
    isTransformable: resolvedCommon.isTransformable,
  );
}

PathNodeSpecBacking pathNodeSpecBackingFromValidated({
  NodeSpecCommonSchemaFields? common,
  required PathNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = pathNodeSchemaFieldsFromValidated(fields);
  return PathNodeSpecBacking(
    id: resolvedCommon.id,
    svgPathData: resolvedFields.svgPathData,
    fillColor: resolvedFields.fillColor,
    strokeColor: resolvedFields.strokeColor,
    strokeWidth: resolvedFields.strokeWidth,
    fillRule: resolvedFields.fillRule,
    transform: resolvedCommon.transform,
    opacity: resolvedCommon.opacity,
    hitPadding: resolvedCommon.hitPadding,
    isVisible: resolvedCommon.isVisible,
    isSelectable: resolvedCommon.isSelectable,
    isLocked: resolvedCommon.isLocked,
    isDeletable: resolvedCommon.isDeletable,
    isTransformable: resolvedCommon.isTransformable,
  );
}

NodeSpecCommonSchemaFields _defaultNodeSpecCommonSchemaFields() => (
  id: null,
  transform: Transform2D.identity,
  opacity: 1,
  hitPadding: 0,
  isVisible: true,
  isSelectable: true,
  isLocked: false,
  isDeletable: true,
  isTransformable: true,
);
