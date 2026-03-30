import 'dart:ui';

import '../ids.dart';
import '../owned_collections.dart';
import '../path_fill_rule.dart';
import '../transform2d.dart';
import '../validated.dart';
import '../validated/validated_value_support.dart';

typedef ImageNodeSchemaFields = ({
  String imageId,
  Size size,
  Size? naturalSize,
});

typedef LineNodeSchemaFields = ({
  Offset start,
  Offset end,
  double thickness,
  Color color,
});

typedef RectNodeSchemaFields = ({
  Size size,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth,
});

typedef PathNodeSchemaFields = ({
  String svgPathData,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth,
  PathFillRule fillRule,
});

typedef NodeDirectionalCommonSchemaFields = ({
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef TextNodeDirectionalSchemaFields = ({
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

NodeId validateRequiredNodeId(NodeId id) {
  return NodeIdValue.of(id, name: 'id').value;
}

NodeId validateNodeIdValue(NodeId value, {required String name}) {
  return NodeIdValue.of(value, name: name).value;
}

int validateInstanceRevisionValue(
  int value, {
  required String name,
  bool allowZero = false,
}) {
  return InstanceRevisionValue.of(
    value,
    name: name,
    allowZero: allowZero,
  ).value;
}

Offset validateFiniteOffsetValue(Offset value, {required String name}) {
  return FiniteOffsetValue.of(value, name: name).value;
}

double validateOpacityValue(double value, {required String name}) {
  return OpacityValue.of(value, name: name).value;
}

double validateNonNegativeFiniteDoubleValue(
  double value, {
  required String name,
}) {
  return NonNegativeFiniteDoubleValue.of(value, name: name).value;
}

double validatePositiveFiniteDoubleValue(double value, {required String name}) {
  return PositiveFiniteDoubleValue.of(value, name: name).value;
}

String validateImageIdValue(String value, {required String name}) {
  return ImageIdValue.of(value, name: name).value;
}

String validateSvgPathDataValue(String value, {required String name}) {
  return SvgPathDataValue.of(value, name: name).value;
}

String validateTextContentValue(String value, {required String name}) {
  return TextContentValue.of(value, name: name).value;
}

String validateFontFamilyValue(String value, {required String name}) {
  return FontFamilyValue.of(value, name: name).value;
}

Transform2D validateFiniteInvertibleTransform2D(
  Transform2D value, {
  required String name,
}) {
  validatedRequireFiniteDouble(value.a, name: '$name.a');
  validatedRequireFiniteDouble(value.b, name: '$name.b');
  validatedRequireFiniteDouble(value.c, name: '$name.c');
  validatedRequireFiniteDouble(value.d, name: '$name.d');
  validatedRequireFiniteDouble(value.tx, name: '$name.tx');
  validatedRequireFiniteDouble(value.ty, name: '$name.ty');
  if (value.invert() == null) {
    throw ArgumentError.value(
      value.toJsonMap(),
      name,
      'Must be invertible (non-singular).',
    );
  }
  return value;
}

Size validateNonNegativeSize(Size value, {required String name}) {
  return Size(
    NonNegativeFiniteDoubleValue.of(value.width, name: '$name.width').value,
    NonNegativeFiniteDoubleValue.of(value.height, name: '$name.height').value,
  );
}

OwnedList<Offset> validateFiniteOffsetList(
  List<Offset> values, {
  required String name,
}) {
  return OwnedList<Offset>.of(
    List<Offset>.generate(
      values.length,
      (index) =>
          FiniteOffsetValue.of(values[index], name: '$name[$index]').value,
      growable: false,
    ),
  );
}

ImageNodeSchemaFields validateImageNodeSchemaFields(
  ImageNodeSchemaFields fields,
) {
  final resolvedNaturalSize = fields.naturalSize;
  return (
    imageId: validateImageIdValue(fields.imageId, name: 'imageId'),
    size: validateNonNegativeSize(fields.size, name: 'size'),
    naturalSize: resolvedNaturalSize == null
        ? null
        : validateNonNegativeSize(resolvedNaturalSize, name: 'naturalSize'),
  );
}

ImageNodeSchemaFields imageNodeSchemaFieldsFromValidated(
  ImageNodeSchemaFields fields,
) => fields;

LineNodeSchemaFields validateLineNodeSchemaFields(LineNodeSchemaFields fields) {
  return (
    start: validateFiniteOffsetValue(fields.start, name: 'start'),
    end: validateFiniteOffsetValue(fields.end, name: 'end'),
    thickness: validatePositiveFiniteDoubleValue(
      fields.thickness,
      name: 'thickness',
    ),
    color: fields.color,
  );
}

LineNodeSchemaFields lineNodeSchemaFieldsFromValidated(
  LineNodeSchemaFields fields,
) => fields;

RectNodeSchemaFields validateRectNodeSchemaFields(RectNodeSchemaFields fields) {
  return (
    size: validateNonNegativeSize(fields.size, name: 'size'),
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: validateNonNegativeFiniteDoubleValue(
      fields.strokeWidth,
      name: 'strokeWidth',
    ),
  );
}

RectNodeSchemaFields rectNodeSchemaFieldsFromValidated(
  RectNodeSchemaFields fields,
) => fields;

PathNodeSchemaFields validatePathNodeSchemaFields(PathNodeSchemaFields fields) {
  return (
    svgPathData: validateSvgPathDataValue(
      fields.svgPathData,
      name: 'svgPathData',
    ),
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: validateNonNegativeFiniteDoubleValue(
      fields.strokeWidth,
      name: 'strokeWidth',
    ),
    fillRule: fields.fillRule,
  );
}

PathNodeSchemaFields pathNodeSchemaFieldsFromValidated(
  PathNodeSchemaFields fields,
) => fields;

NodeDirectionalCommonSchemaFields validateNodeDirectionalCommonSchemaFields(
  NodeDirectionalCommonSchemaFields fields,
) {
  return (
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

NodeDirectionalCommonSchemaFields
nodeDirectionalCommonSchemaFieldsFromValidated(
  NodeDirectionalCommonSchemaFields fields,
) => fields;

TextNodeDirectionalSchemaFields validateTextNodeDirectionalSchemaFields(
  TextNodeDirectionalSchemaFields fields,
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

TextNodeDirectionalSchemaFields textNodeDirectionalSchemaFieldsFromValidated(
  TextNodeDirectionalSchemaFields fields,
) => fields;
