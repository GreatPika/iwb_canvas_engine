part of 'node_boundary_schema.dart';

NodeSnapshotCommonSchemaFields _validateSnapshotCommon(
  NodeSnapshotCommonSchemaFields fields,
) {
  return (
    id: NodeIdValue.of(fields.id, name: 'id').value,
    instanceRevision: InstanceRevisionValue.of(
      fields.instanceRevision,
      name: 'instanceRevision',
      allowZero: true,
    ).value,
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

TextNodeSnapshotSchemaFields _validateTextSnapshotFields(
  TextNodeSnapshotSchemaFields fields,
) {
  final textFields = _validateTextSpecFields((
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
  ));
  return (
    text: textFields.text,
    size: validateNonNegativeSize(fields.size, name: 'size'),
    fontSize: textFields.fontSize,
    color: textFields.color,
    align: textFields.align,
    isBold: textFields.isBold,
    isItalic: textFields.isItalic,
    isUnderline: textFields.isUnderline,
    fontFamily: textFields.fontFamily,
    maxWidth: textFields.maxWidth,
    lineHeight: textFields.lineHeight,
  );
}

StrokeNodeSnapshotSchemaFields _validateStrokeSnapshotFields(
  StrokeNodeSnapshotSchemaInput fields,
) {
  final strokeFields = _validateStrokeSpecFields((
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
  ));
  return (
    points: strokeFields.points,
    pointsRevision: InstanceRevisionValue.of(
      fields.pointsRevision,
      name: 'pointsRevision',
      allowZero: true,
    ).value,
    thickness: strokeFields.thickness,
    color: strokeFields.color,
  );
}

StrokeNodeSnapshotSchemaFields _strokeSnapshotFieldsFromValidated(
  StrokeNodeSnapshotSchemaInput fields,
) {
  final strokeFields = _strokeSpecFieldsFromValidated((
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
  ));
  return (
    points: strokeFields.points,
    pointsRevision: fields.pointsRevision,
    thickness: strokeFields.thickness,
    color: strokeFields.color,
  );
}
