part of 'node_boundary_schema.dart';

NodePatchCommonSchemaFields _validatePatchCommon(
  NodePatchCommonSchemaFields fields,
) {
  return (
    transform: _validateNonNullablePatchField(
      fields.transform,
      name: 'transform',
      transformValue: (value) =>
          validateFiniteInvertibleTransform2D(value, name: 'transform'),
    ),
    opacity: _validateNonNullablePatchField(
      fields.opacity,
      name: 'opacity',
      transformValue: (value) => OpacityValue.of(value, name: 'opacity').value,
    ),
    hitPadding: _validateNonNullablePatchField(
      fields.hitPadding,
      name: 'hitPadding',
      transformValue: (value) =>
          NonNegativeFiniteDoubleValue.of(value, name: 'hitPadding').value,
    ),
    isVisible: fields.isVisible,
    isSelectable: fields.isSelectable,
    isLocked: fields.isLocked,
    isDeletable: fields.isDeletable,
    isTransformable: fields.isTransformable,
  );
}

NodePatchCommonSchemaFields _patchCommonFromValidated(
  NodePatchCommonSchemaFields fields,
) {
  return fields;
}

ImageNodePatchSchemaFields _validateImagePatch(
  ImageNodePatchSchemaFields fields,
) {
  return (
    imageId: _validateNonNullablePatchField(
      fields.imageId,
      name: 'imageId',
      transformValue: (value) => ImageIdValue.of(value, name: 'imageId').value,
    ),
    size: _validateNonNullablePatchField(
      fields.size,
      name: 'size',
      transformValue: (value) => validateNonNegativeSize(value, name: 'size'),
    ),
    naturalSize: _validateNullablePatchField(
      fields.naturalSize,
      transformValue: (value) =>
          validateNonNegativeSize(value, name: 'naturalSize'),
    ),
  );
}

TextNodePatchSchemaFields _validateTextPatch(TextNodePatchSchemaFields fields) {
  return (
    text: _validateNonNullablePatchField(
      fields.text,
      name: 'text',
      transformValue: (value) => TextContentValue.of(value, name: 'text').value,
    ),
    fontSize: _validateNonNullablePatchField(
      fields.fontSize,
      name: 'fontSize',
      transformValue: (value) =>
          PositiveFiniteDoubleValue.of(value, name: 'fontSize').value,
    ),
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: _validateNullablePatchField(
      fields.fontFamily,
      transformValue: (value) =>
          FontFamilyValue.of(value, name: 'fontFamily').value,
    ),
    maxWidth: _validateNullablePatchField(
      fields.maxWidth,
      transformValue: (value) =>
          PositiveFiniteDoubleValue.of(value, name: 'maxWidth').value,
    ),
    lineHeight: _validateNullablePatchField(
      fields.lineHeight,
      transformValue: (value) =>
          PositiveFiniteDoubleValue.of(value, name: 'lineHeight').value,
    ),
  );
}

StrokeNodePatchSchemaFields _validateStrokePatch(
  StrokeNodePatchSchemaFields fields,
) {
  return (
    points: _validateNonNullablePatchField(
      fields.points,
      name: 'points',
      transformValue: (value) =>
          validateFiniteOffsetList(value, name: 'points'),
    ),
    thickness: _validateNonNullablePatchField(
      fields.thickness,
      name: 'thickness',
      transformValue: (value) =>
          PositiveFiniteDoubleValue.of(value, name: 'thickness').value,
    ),
    color: fields.color,
  );
}

StrokeNodePatchSchemaFields _strokePatchFromValidated(
  StrokeNodePatchSchemaFields fields,
) {
  return (
    points: snapshotOffsetListPatchField(fields.points),
    thickness: fields.thickness,
    color: fields.color,
  );
}

LineNodePatchSchemaFields _validateLinePatch(LineNodePatchSchemaFields fields) {
  return (
    start: _validateNonNullablePatchField(
      fields.start,
      name: 'start',
      transformValue: (value) =>
          FiniteOffsetValue.of(value, name: 'start').value,
    ),
    end: _validateNonNullablePatchField(
      fields.end,
      name: 'end',
      transformValue: (value) => FiniteOffsetValue.of(value, name: 'end').value,
    ),
    thickness: _validateNonNullablePatchField(
      fields.thickness,
      name: 'thickness',
      transformValue: (value) =>
          PositiveFiniteDoubleValue.of(value, name: 'thickness').value,
    ),
    color: fields.color,
  );
}

RectNodePatchSchemaFields _validateRectPatch(RectNodePatchSchemaFields fields) {
  return (
    size: _validateNonNullablePatchField(
      fields.size,
      name: 'size',
      transformValue: (value) => validateNonNegativeSize(value, name: 'size'),
    ),
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: _validateNonNullablePatchField(
      fields.strokeWidth,
      name: 'strokeWidth',
      transformValue: (value) =>
          NonNegativeFiniteDoubleValue.of(value, name: 'strokeWidth').value,
    ),
  );
}

PathNodePatchSchemaFields _validatePathPatch(PathNodePatchSchemaFields fields) {
  return (
    svgPathData: _validateNonNullablePatchField(
      fields.svgPathData,
      name: 'svgPathData',
      transformValue: (value) =>
          SvgPathDataValue.of(value, name: 'svgPathData').value,
    ),
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: _validateNonNullablePatchField(
      fields.strokeWidth,
      name: 'strokeWidth',
      transformValue: (value) =>
          NonNegativeFiniteDoubleValue.of(value, name: 'strokeWidth').value,
    ),
    fillRule: fields.fillRule,
  );
}
