part of '../node_patch.dart';

@internal
CommonNodePatch commonNodePatchFromValidated({
  NodePatchCommonSchemaFields? fields,
}) {
  final resolved = NodeBoundarySchema.patchCommonFromValidated(
    fields ?? _defaultNodePatchCommonSchemaFields(),
  );
  return CommonNodePatch._internal(
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

@internal
ImageNodePatch imageNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  ImageNodePatchSchemaFields? fields,
}) {
  final resolvedCommon = common ?? commonNodePatchFromValidated();
  final resolvedFields = NodeBoundarySchema.imagePatchFromValidated(
    fields ?? _defaultImageNodePatchSchemaFields(),
  );
  return ImageNodePatch._internal(
    id: id,
    common: resolvedCommon,
    imageId: resolvedFields.imageId,
    size: resolvedFields.size,
    naturalSize: resolvedFields.naturalSize,
  );
}

@internal
TextNodePatch textNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  TextNodePatchSchemaFields? fields,
}) {
  final resolvedCommon = common ?? commonNodePatchFromValidated();
  final resolvedFields = NodeBoundarySchema.textPatchFromValidated(
    fields ?? _defaultTextNodePatchSchemaFields(),
  );
  return TextNodePatch._internal(
    id: id,
    common: resolvedCommon,
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
  );
}

@internal
StrokeNodePatch strokeNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  StrokeNodePatchSchemaFields? fields,
}) {
  final resolvedCommon = common ?? commonNodePatchFromValidated();
  final resolvedFields = NodeBoundarySchema.strokePatchFromValidated(
    fields ?? _defaultStrokeNodePatchSchemaFields(),
  );
  return StrokeNodePatch._internal(
    id: id,
    common: resolvedCommon,
    points: resolvedFields.points,
    thickness: resolvedFields.thickness,
    color: resolvedFields.color,
  );
}

@internal
LineNodePatch lineNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  LineNodePatchSchemaFields? fields,
}) {
  final resolvedCommon = common ?? commonNodePatchFromValidated();
  final resolvedFields = NodeBoundarySchema.linePatchFromValidated(
    fields ?? _defaultLineNodePatchSchemaFields(),
  );
  return LineNodePatch._internal(
    id: id,
    common: resolvedCommon,
    start: resolvedFields.start,
    end: resolvedFields.end,
    thickness: resolvedFields.thickness,
    color: resolvedFields.color,
  );
}

@internal
RectNodePatch rectNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  RectNodePatchSchemaFields? fields,
}) {
  final resolvedCommon = common ?? commonNodePatchFromValidated();
  final resolvedFields = NodeBoundarySchema.rectPatchFromValidated(
    fields ?? _defaultRectNodePatchSchemaFields(),
  );
  return RectNodePatch._internal(
    id: id,
    common: resolvedCommon,
    size: resolvedFields.size,
    fillColor: resolvedFields.fillColor,
    strokeColor: resolvedFields.strokeColor,
    strokeWidth: resolvedFields.strokeWidth,
  );
}

@internal
PathNodePatch pathNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PathNodePatchSchemaFields? fields,
}) {
  final resolvedCommon = common ?? commonNodePatchFromValidated();
  final resolvedFields = NodeBoundarySchema.pathPatchFromValidated(
    fields ?? _defaultPathNodePatchSchemaFields(),
  );
  return PathNodePatch._internal(
    id: id,
    common: resolvedCommon,
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
