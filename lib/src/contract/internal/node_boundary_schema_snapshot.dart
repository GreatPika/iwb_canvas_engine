import 'dart:ui';

import '../ids.dart';
import '../owned_collections.dart';
import '../transform2d.dart';
import 'node_boundary_schema_common.dart';
import 'node_boundary_schema_spec.dart';

typedef NodeSnapshotCommonSchemaFields = ({
  NodeId id,
  int instanceRevision,
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef TextNodeSnapshotSchemaFields = ({
  String text,
  Size size,
  double fontSize,
  Color color,
  TextAlign align,
  bool isBold,
  bool isItalic,
  bool isUnderline,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
});

typedef StrokeNodeSnapshotSchemaInput = ({
  List<Offset> points,
  int pointsRevision,
  double thickness,
  Color color,
});

typedef StrokeNodeSnapshotSchemaFields = ({
  OwnedList<Offset> points,
  int pointsRevision,
  double thickness,
  Color color,
});

NodeSnapshotCommonSchemaFields validateSnapshotCommonSchemaFields(
  NodeSnapshotCommonSchemaFields fields,
) {
  return (
    id: validateNodeIdValue(fields.id, name: 'id'),
    instanceRevision: validateInstanceRevisionValue(
      fields.instanceRevision,
      name: 'instanceRevision',
      allowZero: true,
    ),
    transform: validateFiniteInvertibleTransform2D(
      fields.transform,
      name: 'transform',
    ),
    opacity: validateOpacityValue(fields.opacity, name: 'opacity'),
    hitPadding: validateNonNegativeFiniteDoubleValue(
      fields.hitPadding,
      name: 'hitPadding',
    ),
    isVisible: fields.isVisible,
    isSelectable: fields.isSelectable,
    isLocked: fields.isLocked,
    isDeletable: fields.isDeletable,
    isTransformable: fields.isTransformable,
  );
}

NodeSnapshotCommonSchemaFields snapshotCommonSchemaFieldsFromValidated(
  NodeSnapshotCommonSchemaFields fields,
) => fields;

TextNodeSnapshotSchemaFields validateTextNodeSnapshotSchemaFields(
  TextNodeSnapshotSchemaFields fields,
) {
  final textFields = validateTextNodeSpecSchemaFields((
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

TextNodeSnapshotSchemaFields textNodeSnapshotSchemaFieldsFromValidated(
  TextNodeSnapshotSchemaFields fields,
) => fields;

StrokeNodeSnapshotSchemaFields validateStrokeNodeSnapshotSchemaFields(
  StrokeNodeSnapshotSchemaInput fields,
) {
  final strokeFields = validateStrokeNodeSpecSchemaFields((
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
  ));
  return (
    points: strokeFields.points,
    pointsRevision: validateInstanceRevisionValue(
      fields.pointsRevision,
      name: 'pointsRevision',
      allowZero: true,
    ),
    thickness: strokeFields.thickness,
    color: strokeFields.color,
  );
}

StrokeNodeSnapshotSchemaFields strokeNodeSnapshotSchemaFieldsFromValidated(
  StrokeNodeSnapshotSchemaInput fields,
) {
  final strokeFields = strokeNodeSpecSchemaFieldsFromValidated((
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
