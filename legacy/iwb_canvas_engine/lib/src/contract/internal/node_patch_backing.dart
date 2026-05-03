import 'dart:ui';

import '../ids.dart';
import '../patch_field.dart';
import '../path_fill_rule.dart';
import '../snapshot.dart' hide PathFillRule;
import '../transform2d.dart';
import 'node_boundary_schema.dart';

final class CommonNodePatchBacking {
  const CommonNodePatchBacking({
    this.transform = const PatchField<Transform2D>.absent(),
    this.opacity = const PatchField<double>.absent(),
    this.hitPadding = const PatchField<double>.absent(),
    this.isVisible = const PatchField<bool>.absent(),
    this.isSelectable = const PatchField<bool>.absent(),
    this.isLocked = const PatchField<bool>.absent(),
    this.isDeletable = const PatchField<bool>.absent(),
    this.isTransformable = const PatchField<bool>.absent(),
  });

  final PatchField<Transform2D> transform;
  final PatchField<double> opacity;
  final PatchField<double> hitPadding;
  final PatchField<bool> isVisible;
  final PatchField<bool> isSelectable;
  final PatchField<bool> isLocked;
  final PatchField<bool> isDeletable;
  final PatchField<bool> isTransformable;
}

sealed class NodePatchBacking {
  const NodePatchBacking({required this.id, required this.common});

  final NodeId id;
  final CommonNodePatchBacking common;
}

final class ImageNodePatchBacking extends NodePatchBacking {
  const ImageNodePatchBacking({
    required super.id,
    required super.common,
    this.imageId = const PatchField<String>.absent(),
    this.size = const PatchField<Size>.absent(),
    this.naturalSize = const PatchField<Size?>.absent(),
  });

  final PatchField<String> imageId;
  final PatchField<Size> size;
  final PatchField<Size?> naturalSize;
}

final class TextNodePatchBacking extends NodePatchBacking {
  const TextNodePatchBacking({
    required super.id,
    required super.common,
    this.text = const PatchField<String>.absent(),
    this.fontSize = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
    this.align = const PatchField<TextAlign>.absent(),
    this.textDirection = const PatchField<TextDirection>.absent(),
    this.isBold = const PatchField<bool>.absent(),
    this.isItalic = const PatchField<bool>.absent(),
    this.isUnderline = const PatchField<bool>.absent(),
    this.fontFamily = const PatchField<String?>.absent(),
    this.maxWidth = const PatchField<double?>.absent(),
    this.lineHeight = const PatchField<double?>.absent(),
  });

  final PatchField<String> text;
  final PatchField<double> fontSize;
  final PatchField<Color> color;
  final PatchField<TextAlign> align;
  final PatchField<TextDirection> textDirection;
  final PatchField<bool> isBold;
  final PatchField<bool> isItalic;
  final PatchField<bool> isUnderline;
  final PatchField<String?> fontFamily;
  final PatchField<double?> maxWidth;
  final PatchField<double?> lineHeight;
}

final class StrokeNodePatchBacking extends NodePatchBacking {
  StrokeNodePatchBacking({
    required super.id,
    required super.common,
    PatchField<List<Offset>> points = const PatchField<List<Offset>>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  }) : points = snapshotOffsetListPatchField(points);

  final PatchField<List<Offset>> points;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

final class LineNodePatchBacking extends NodePatchBacking {
  const LineNodePatchBacking({
    required super.id,
    required super.common,
    this.start = const PatchField<Offset>.absent(),
    this.end = const PatchField<Offset>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  });

  final PatchField<Offset> start;
  final PatchField<Offset> end;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

final class RectNodePatchBacking extends NodePatchBacking {
  const RectNodePatchBacking({
    required super.id,
    required super.common,
    this.size = const PatchField<Size>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
  });

  final PatchField<Size> size;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
}

final class PathNodePatchBacking extends NodePatchBacking {
  const PathNodePatchBacking({
    required super.id,
    required super.common,
    this.svgPathData = const PatchField<String>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
    this.fillRule = const PatchField<PathFillRule>.absent(),
  });

  final PatchField<String> svgPathData;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
  final PatchField<PathFillRule> fillRule;
}

CommonNodePatchBacking commonNodePatchBackingFromValidated({
  NodePatchCommonSchemaFields? fields,
}) {
  final resolved = patchCommonSchemaFieldsFromValidated(
    fields ?? _defaultNodePatchCommonSchemaFields(),
  );
  return CommonNodePatchBacking(
    transform: resolved.transform,
    opacity: resolved.opacity,
    hitPadding: resolved.hitPadding,
    isVisible: resolved.isVisible,
    isSelectable: resolved.isSelectable,
    isLocked: resolved.isLocked,
    isDeletable: resolved.isDeletable,
    isTransformable: resolved.isTransformable,
  );
}

ImageNodePatchBacking imageNodePatchBackingFromValidated({
  required NodeId id,
  CommonNodePatchBacking? common,
  ImageNodePatchSchemaFields? fields,
}) {
  final resolvedFields = imageNodePatchSchemaFieldsFromValidated(
    fields ?? _defaultImageNodePatchSchemaFields(),
  );
  return ImageNodePatchBacking(
    id: id,
    common: common ?? commonNodePatchBackingFromValidated(),
    imageId: resolvedFields.imageId,
    size: resolvedFields.size,
    naturalSize: resolvedFields.naturalSize,
  );
}

TextNodePatchBacking textNodePatchBackingFromValidated({
  required NodeId id,
  CommonNodePatchBacking? common,
  TextNodePatchSchemaFields? fields,
}) {
  final resolvedFields = textNodePatchSchemaFieldsFromValidated(
    fields ?? _defaultTextNodePatchSchemaFields(),
  );
  return TextNodePatchBacking(
    id: id,
    common: common ?? commonNodePatchBackingFromValidated(),
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
  );
}

StrokeNodePatchBacking strokeNodePatchBackingFromValidated({
  required NodeId id,
  CommonNodePatchBacking? common,
  StrokeNodePatchSchemaFields? fields,
}) {
  final resolvedFields = strokeNodePatchSchemaFieldsFromValidated(
    fields ?? _defaultStrokeNodePatchSchemaFields(),
  );
  return StrokeNodePatchBacking(
    id: id,
    common: common ?? commonNodePatchBackingFromValidated(),
    points: resolvedFields.points,
    thickness: resolvedFields.thickness,
    color: resolvedFields.color,
  );
}

LineNodePatchBacking lineNodePatchBackingFromValidated({
  required NodeId id,
  CommonNodePatchBacking? common,
  LineNodePatchSchemaFields? fields,
}) {
  final resolvedFields = lineNodePatchSchemaFieldsFromValidated(
    fields ?? _defaultLineNodePatchSchemaFields(),
  );
  return LineNodePatchBacking(
    id: id,
    common: common ?? commonNodePatchBackingFromValidated(),
    start: resolvedFields.start,
    end: resolvedFields.end,
    thickness: resolvedFields.thickness,
    color: resolvedFields.color,
  );
}

RectNodePatchBacking rectNodePatchBackingFromValidated({
  required NodeId id,
  CommonNodePatchBacking? common,
  RectNodePatchSchemaFields? fields,
}) {
  final resolvedFields = rectNodePatchSchemaFieldsFromValidated(
    fields ?? _defaultRectNodePatchSchemaFields(),
  );
  return RectNodePatchBacking(
    id: id,
    common: common ?? commonNodePatchBackingFromValidated(),
    size: resolvedFields.size,
    fillColor: resolvedFields.fillColor,
    strokeColor: resolvedFields.strokeColor,
    strokeWidth: resolvedFields.strokeWidth,
  );
}

PathNodePatchBacking pathNodePatchBackingFromValidated({
  required NodeId id,
  CommonNodePatchBacking? common,
  PathNodePatchSchemaFields? fields,
}) {
  final resolvedFields = pathNodePatchSchemaFieldsFromValidated(
    fields ?? _defaultPathNodePatchSchemaFields(),
  );
  return PathNodePatchBacking(
    id: id,
    common: common ?? commonNodePatchBackingFromValidated(),
    svgPathData: resolvedFields.svgPathData,
    fillColor: resolvedFields.fillColor,
    strokeColor: resolvedFields.strokeColor,
    strokeWidth: resolvedFields.strokeWidth,
    fillRule: resolvedFields.fillRule,
  );
}

NodePatchCommonSchemaFields _defaultNodePatchCommonSchemaFields() => (
  transform: const PatchField<Transform2D>.absent(),
  opacity: const PatchField<double>.absent(),
  hitPadding: const PatchField<double>.absent(),
  isVisible: const PatchField<bool>.absent(),
  isSelectable: const PatchField<bool>.absent(),
  isLocked: const PatchField<bool>.absent(),
  isDeletable: const PatchField<bool>.absent(),
  isTransformable: const PatchField<bool>.absent(),
);

ImageNodePatchSchemaFields _defaultImageNodePatchSchemaFields() => (
  imageId: const PatchField<String>.absent(),
  size: const PatchField<Size>.absent(),
  naturalSize: const PatchField<Size?>.absent(),
);

TextNodePatchSchemaFields _defaultTextNodePatchSchemaFields() => (
  text: const PatchField<String>.absent(),
  fontSize: const PatchField<double>.absent(),
  color: const PatchField<Color>.absent(),
  align: const PatchField<TextAlign>.absent(),
  textDirection: const PatchField<TextDirection>.absent(),
  isBold: const PatchField<bool>.absent(),
  isItalic: const PatchField<bool>.absent(),
  isUnderline: const PatchField<bool>.absent(),
  fontFamily: const PatchField<String?>.absent(),
  maxWidth: const PatchField<double?>.absent(),
  lineHeight: const PatchField<double?>.absent(),
);

StrokeNodePatchSchemaFields _defaultStrokeNodePatchSchemaFields() => (
  points: const PatchField<List<Offset>>.absent(),
  thickness: const PatchField<double>.absent(),
  color: const PatchField<Color>.absent(),
);

LineNodePatchSchemaFields _defaultLineNodePatchSchemaFields() => (
  start: const PatchField<Offset>.absent(),
  end: const PatchField<Offset>.absent(),
  thickness: const PatchField<double>.absent(),
  color: const PatchField<Color>.absent(),
);

RectNodePatchSchemaFields _defaultRectNodePatchSchemaFields() => (
  size: const PatchField<Size>.absent(),
  fillColor: const PatchField<Color?>.absent(),
  strokeColor: const PatchField<Color?>.absent(),
  strokeWidth: const PatchField<double>.absent(),
);

PathNodePatchSchemaFields _defaultPathNodePatchSchemaFields() => (
  svgPathData: const PatchField<String>.absent(),
  fillColor: const PatchField<Color?>.absent(),
  strokeColor: const PatchField<Color?>.absent(),
  strokeWidth: const PatchField<double>.absent(),
  fillRule: const PatchField<PathFillRule>.absent(),
);
