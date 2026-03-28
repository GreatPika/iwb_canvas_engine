import 'package:flutter/foundation.dart';

import '../node_spec.dart';
import '../transform2d.dart';
import 'node_boundary_schema.dart';

@internal
ImageNodeSpec imageNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required ImageNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = imageNodeSchemaFieldsFromValidated(fields);
  return ImageNodeSpec(
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

@internal
TextNodeSpec textNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required TextNodeSpecSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = textNodeSpecSchemaFieldsFromValidated(fields);
  return TextNodeSpec(
    id: resolvedCommon.id,
    text: resolvedFields.text,
    fontSize: resolvedFields.fontSize,
    color: resolvedFields.color,
    align: resolvedFields.align,
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

@internal
StrokeNodeSpec strokeNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required StrokeNodeSpecSchemaInput fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = strokeNodeSpecSchemaFieldsFromValidated(fields);
  return StrokeNodeSpec(
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

@internal
LineNodeSpec lineNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required LineNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = lineNodeSchemaFieldsFromValidated(fields);
  return LineNodeSpec(
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

@internal
RectNodeSpec rectNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required RectNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = rectNodeSchemaFieldsFromValidated(fields);
  return RectNodeSpec(
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

@internal
PathNodeSpec pathNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required PathNodeSchemaFields fields,
}) {
  final resolvedCommon = specCommonSchemaFieldsFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = pathNodeSchemaFieldsFromValidated(fields);
  return PathNodeSpec(
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
