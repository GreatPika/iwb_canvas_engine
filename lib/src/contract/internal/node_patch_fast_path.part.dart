part of '../node_patch.dart';

@internal
CommonNodePatch commonNodePatchFromValidated({
  NodePatchCommonSchemaFields? fields,
}) {
  return _commonNodePatchFromSchema(
    NodeBoundarySchema.patchCommonFromValidated(
      fields ?? _defaultNodePatchCommonSchemaFields(),
    ),
  );
}

@internal
ImageNodePatch imageNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  ImageNodePatchSchemaFields? fields,
}) {
  return _imageNodePatchFromSchema(
    id: id,
    common: common ?? commonNodePatchFromValidated(),
    fields: NodeBoundarySchema.imagePatchFromValidated(
      fields ?? _defaultImageNodePatchSchemaFields(),
    ),
  );
}

@internal
TextNodePatch textNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  TextNodePatchSchemaFields? fields,
}) {
  return _textNodePatchFromSchema(
    id: id,
    common: common ?? commonNodePatchFromValidated(),
    fields: NodeBoundarySchema.textPatchFromValidated(
      fields ?? _defaultTextNodePatchSchemaFields(),
    ),
  );
}

@internal
StrokeNodePatch strokeNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  StrokeNodePatchSchemaFields? fields,
}) {
  return _strokeNodePatchFromSchema(
    id: id,
    common: common ?? commonNodePatchFromValidated(),
    fields: NodeBoundarySchema.strokePatchFromValidated(
      fields ?? _defaultStrokeNodePatchSchemaFields(),
    ),
  );
}

@internal
LineNodePatch lineNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  LineNodePatchSchemaFields? fields,
}) {
  return _lineNodePatchFromSchema(
    id: id,
    common: common ?? commonNodePatchFromValidated(),
    fields: NodeBoundarySchema.linePatchFromValidated(
      fields ?? _defaultLineNodePatchSchemaFields(),
    ),
  );
}

@internal
RectNodePatch rectNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  RectNodePatchSchemaFields? fields,
}) {
  return _rectNodePatchFromSchema(
    id: id,
    common: common ?? commonNodePatchFromValidated(),
    fields: NodeBoundarySchema.rectPatchFromValidated(
      fields ?? _defaultRectNodePatchSchemaFields(),
    ),
  );
}

@internal
PathNodePatch pathNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PathNodePatchSchemaFields? fields,
}) {
  return _pathNodePatchFromSchema(
    id: id,
    common: common ?? commonNodePatchFromValidated(),
    fields: NodeBoundarySchema.pathPatchFromValidated(
      fields ?? _defaultPathNodePatchSchemaFields(),
    ),
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
