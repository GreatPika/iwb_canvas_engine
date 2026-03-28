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
  return (
    id: resolvedId == null ? null : validateNodeIdValue(resolvedId, name: 'id'),
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

NodeSpecCommonSchemaFields specCommonSchemaFieldsFromValidated(
  NodeSpecCommonSchemaFields fields,
) => fields;

TextNodeSpecSchemaFields validateTextNodeSpecSchemaFields(
  TextNodeSpecSchemaFields fields,
) {
  final resolvedFontFamily = fields.fontFamily;
  final resolvedMaxWidth = fields.maxWidth;
  final resolvedLineHeight = fields.lineHeight;
  return (
    text: validateTextContentValue(fields.text, name: 'text'),
    fontSize: validatePositiveFiniteDoubleValue(
      fields.fontSize,
      name: 'fontSize',
    ),
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: resolvedFontFamily == null
        ? null
        : validateFontFamilyValue(resolvedFontFamily, name: 'fontFamily'),
    maxWidth: resolvedMaxWidth == null
        ? null
        : validatePositiveFiniteDoubleValue(resolvedMaxWidth, name: 'maxWidth'),
    lineHeight: resolvedLineHeight == null
        ? null
        : validatePositiveFiniteDoubleValue(
            resolvedLineHeight,
            name: 'lineHeight',
          ),
  );
}

TextNodeSpecSchemaFields textNodeSpecSchemaFieldsFromValidated(
  TextNodeSpecSchemaFields fields,
) => fields;

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
