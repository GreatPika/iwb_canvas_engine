part of 'node_boundary_schema.dart';

NodeSpecCommonSchemaFields _validateSpecCommon(
  NodeSpecCommonSchemaFields fields,
) {
  final resolvedId = fields.id;
  return (
    id: resolvedId == null
        ? null
        : NodeIdValue.of(resolvedId, name: 'id').value,
    transform: validateFiniteInvertibleTransform2D(
      fields.transform,
      name: 'transform',
    ),
    opacity: OpacityValue.of(fields.opacity, name: 'opacity').value,
    hitPadding: NonNegativeFiniteDoubleValue.of(
      fields.hitPadding,
      name: 'hitPadding',
    ).value,
    isVisible: fields.isVisible,
    isSelectable: fields.isSelectable,
    isLocked: fields.isLocked,
    isDeletable: fields.isDeletable,
    isTransformable: fields.isTransformable,
  );
}

ImageNodeSchemaFields _validateImageFields(ImageNodeSchemaFields fields) {
  final resolvedNaturalSize = fields.naturalSize;
  return (
    imageId: ImageIdValue.of(fields.imageId, name: 'imageId').value,
    size: validateNonNegativeSize(fields.size, name: 'size'),
    naturalSize: resolvedNaturalSize == null
        ? null
        : validateNonNegativeSize(resolvedNaturalSize, name: 'naturalSize'),
  );
}

TextNodeSpecSchemaFields _validateTextSpecFields(
  TextNodeSpecSchemaFields fields,
) {
  final resolvedFontFamily = fields.fontFamily;
  final resolvedMaxWidth = fields.maxWidth;
  final resolvedLineHeight = fields.lineHeight;
  return (
    text: TextContentValue.of(fields.text, name: 'text').value,
    fontSize: PositiveFiniteDoubleValue.of(
      fields.fontSize,
      name: 'fontSize',
    ).value,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: resolvedFontFamily == null
        ? null
        : FontFamilyValue.of(resolvedFontFamily, name: 'fontFamily').value,
    maxWidth: resolvedMaxWidth == null
        ? null
        : PositiveFiniteDoubleValue.of(
            resolvedMaxWidth,
            name: 'maxWidth',
          ).value,
    lineHeight: resolvedLineHeight == null
        ? null
        : PositiveFiniteDoubleValue.of(
            resolvedLineHeight,
            name: 'lineHeight',
          ).value,
  );
}

StrokeNodeSpecSchemaFields _validateStrokeSpecFields(
  StrokeNodeSpecSchemaInput fields,
) {
  return (
    points: validateFiniteOffsetList(fields.points, name: 'points'),
    thickness: PositiveFiniteDoubleValue.of(
      fields.thickness,
      name: 'thickness',
    ).value,
    color: fields.color,
  );
}

StrokeNodeSpecSchemaFields _strokeSpecFieldsFromValidated(
  StrokeNodeSpecSchemaInput fields,
) {
  return (
    points: OwnedList<Offset>.of(fields.points),
    thickness: fields.thickness,
    color: fields.color,
  );
}

LineNodeSchemaFields _validateLineFields(LineNodeSchemaFields fields) {
  return (
    start: FiniteOffsetValue.of(fields.start, name: 'start').value,
    end: FiniteOffsetValue.of(fields.end, name: 'end').value,
    thickness: PositiveFiniteDoubleValue.of(
      fields.thickness,
      name: 'thickness',
    ).value,
    color: fields.color,
  );
}

RectNodeSchemaFields _validateRectFields(RectNodeSchemaFields fields) {
  return (
    size: validateNonNegativeSize(fields.size, name: 'size'),
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: NonNegativeFiniteDoubleValue.of(
      fields.strokeWidth,
      name: 'strokeWidth',
    ).value,
  );
}

PathNodeSchemaFields _validatePathFields(PathNodeSchemaFields fields) {
  return (
    svgPathData: SvgPathDataValue.of(
      fields.svgPathData,
      name: 'svgPathData',
    ).value,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: NonNegativeFiniteDoubleValue.of(
      fields.strokeWidth,
      name: 'strokeWidth',
    ).value,
    fillRule: fields.fillRule,
  );
}
