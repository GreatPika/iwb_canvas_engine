part of '../node_spec.dart';

@internal
ImageNodeSpec imageNodeSpecFromValidated({
  NodeSpecCommonSchemaFields? common,
  required ImageNodeSchemaFields fields,
}) {
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = NodeBoundarySchema.imageFieldsFromValidated(fields);
  return ImageNodeSpec._internal(
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
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = NodeBoundarySchema.textSpecFieldsFromValidated(fields);
  return TextNodeSpec._internal(
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
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = NodeBoundarySchema.strokeSpecFieldsFromValidated(
    fields,
  );
  return StrokeNodeSpec._internal(
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
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = NodeBoundarySchema.lineFieldsFromValidated(fields);
  return LineNodeSpec._internal(
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
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = NodeBoundarySchema.rectFieldsFromValidated(fields);
  return RectNodeSpec._internal(
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
  final resolvedCommon = NodeBoundarySchema.specCommonFromValidated(
    common ?? _defaultNodeSpecCommonSchemaFields(),
  );
  final resolvedFields = NodeBoundarySchema.pathFieldsFromValidated(fields);
  return PathNodeSpec._internal(
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
