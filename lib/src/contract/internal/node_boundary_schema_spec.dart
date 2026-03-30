import 'dart:ui';

import '../ids.dart';
import '../owned_collections.dart';
import '../transform2d.dart';
import 'node_boundary_schema_common.dart';

typedef NodeSpecCommonSchemaFields = ({
  NodeId? id,
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef TextNodeSpecSchemaFields = ({
  String text,
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

typedef StrokeNodeSpecSchemaInput = ({
  List<Offset> points,
  double thickness,
  Color color,
});

typedef StrokeNodeSpecSchemaFields = ({
  OwnedList<Offset> points,
  double thickness,
  Color color,
});

NodeSpecCommonSchemaFields validateSpecCommonSchemaFields(
  NodeSpecCommonSchemaFields fields,
) {
  final resolvedId = fields.id;
  final commonFields = validateNodeDirectionalCommonSchemaFields((
    transform: fields.transform,
    opacity: fields.opacity,
    hitPadding: fields.hitPadding,
    isVisible: fields.isVisible,
    isSelectable: fields.isSelectable,
    isLocked: fields.isLocked,
    isDeletable: fields.isDeletable,
    isTransformable: fields.isTransformable,
  ));
  return (
    id: resolvedId == null ? null : validateNodeIdValue(resolvedId, name: 'id'),
    transform: commonFields.transform,
    opacity: commonFields.opacity,
    hitPadding: commonFields.hitPadding,
    isVisible: commonFields.isVisible,
    isSelectable: commonFields.isSelectable,
    isLocked: commonFields.isLocked,
    isDeletable: commonFields.isDeletable,
    isTransformable: commonFields.isTransformable,
  );
}

NodeSpecCommonSchemaFields specCommonSchemaFieldsFromValidated(
  NodeSpecCommonSchemaFields fields,
) {
  final commonFields = nodeDirectionalCommonSchemaFieldsFromValidated((
    transform: fields.transform,
    opacity: fields.opacity,
    hitPadding: fields.hitPadding,
    isVisible: fields.isVisible,
    isSelectable: fields.isSelectable,
    isLocked: fields.isLocked,
    isDeletable: fields.isDeletable,
    isTransformable: fields.isTransformable,
  ));
  return (
    id: fields.id,
    transform: commonFields.transform,
    opacity: commonFields.opacity,
    hitPadding: commonFields.hitPadding,
    isVisible: commonFields.isVisible,
    isSelectable: commonFields.isSelectable,
    isLocked: commonFields.isLocked,
    isDeletable: commonFields.isDeletable,
    isTransformable: commonFields.isTransformable,
  );
}

TextNodeSpecSchemaFields validateTextNodeSpecSchemaFields(
  TextNodeSpecSchemaFields fields,
) {
  final textFields = validateTextNodeDirectionalSchemaFields((
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

TextNodeSpecSchemaFields textNodeSpecSchemaFieldsFromValidated(
  TextNodeSpecSchemaFields fields,
) {
  final textFields = textNodeDirectionalSchemaFieldsFromValidated((
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

StrokeNodeSpecSchemaFields validateStrokeNodeSpecSchemaFields(
  StrokeNodeSpecSchemaInput fields,
) {
  return (
    points: validateFiniteOffsetList(fields.points, name: 'points'),
    thickness: validatePositiveFiniteDoubleValue(
      fields.thickness,
      name: 'thickness',
    ),
    color: fields.color,
  );
}

StrokeNodeSpecSchemaFields strokeNodeSpecSchemaFieldsFromValidated(
  StrokeNodeSpecSchemaInput fields,
) {
  return (
    points: OwnedList<Offset>.of(fields.points),
    thickness: fields.thickness,
    color: fields.color,
  );
}
