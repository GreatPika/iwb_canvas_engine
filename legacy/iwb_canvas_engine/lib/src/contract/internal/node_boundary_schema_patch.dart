import 'dart:ui';

import '../owned_collections.dart';
import '../patch_field.dart';
import '../path_fill_rule.dart';
import '../transform2d.dart';
import 'node_boundary_schema_common.dart';

typedef NodePatchCommonSchemaFields = ({
  PatchField<Transform2D> transform,
  PatchField<double> opacity,
  PatchField<double> hitPadding,
  PatchField<bool> isVisible,
  PatchField<bool> isSelectable,
  PatchField<bool> isLocked,
  PatchField<bool> isDeletable,
  PatchField<bool> isTransformable,
});

typedef ImageNodePatchSchemaFields = ({
  PatchField<String> imageId,
  PatchField<Size> size,
  PatchField<Size?> naturalSize,
});

typedef TextNodePatchSchemaFields = ({
  PatchField<String> text,
  PatchField<double> fontSize,
  PatchField<Color> color,
  PatchField<TextAlign> align,
  PatchField<TextDirection> textDirection,
  PatchField<bool> isBold,
  PatchField<bool> isItalic,
  PatchField<bool> isUnderline,
  PatchField<String?> fontFamily,
  PatchField<double?> maxWidth,
  PatchField<double?> lineHeight,
});

typedef StrokeNodePatchSchemaFields = ({
  PatchField<List<Offset>> points,
  PatchField<double> thickness,
  PatchField<Color> color,
});

typedef LineNodePatchSchemaFields = ({
  PatchField<Offset> start,
  PatchField<Offset> end,
  PatchField<double> thickness,
  PatchField<Color> color,
});

typedef RectNodePatchSchemaFields = ({
  PatchField<Size> size,
  PatchField<Color?> fillColor,
  PatchField<Color?> strokeColor,
  PatchField<double> strokeWidth,
});

typedef PathNodePatchSchemaFields = ({
  PatchField<String> svgPathData,
  PatchField<Color?> fillColor,
  PatchField<Color?> strokeColor,
  PatchField<double> strokeWidth,
  PatchField<PathFillRule> fillRule,
});

NodePatchCommonSchemaFields validatePatchCommonSchemaFields(
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
      transformValue: (value) => validateOpacityValue(value, name: 'opacity'),
    ),
    hitPadding: _validateNonNullablePatchField(
      fields.hitPadding,
      name: 'hitPadding',
      transformValue: (value) =>
          validateNonNegativeFiniteDoubleValue(value, name: 'hitPadding'),
    ),
    isVisible: _validateNonNullablePatchField(
      fields.isVisible,
      name: 'isVisible',
      transformValue: (value) => value,
    ),
    isSelectable: _validateNonNullablePatchField(
      fields.isSelectable,
      name: 'isSelectable',
      transformValue: (value) => value,
    ),
    isLocked: _validateNonNullablePatchField(
      fields.isLocked,
      name: 'isLocked',
      transformValue: (value) => value,
    ),
    isDeletable: _validateNonNullablePatchField(
      fields.isDeletable,
      name: 'isDeletable',
      transformValue: (value) => value,
    ),
    isTransformable: _validateNonNullablePatchField(
      fields.isTransformable,
      name: 'isTransformable',
      transformValue: (value) => value,
    ),
  );
}

NodePatchCommonSchemaFields patchCommonSchemaFieldsFromValidated(
  NodePatchCommonSchemaFields fields,
) => fields;

ImageNodePatchSchemaFields validateImageNodePatchSchemaFields(
  ImageNodePatchSchemaFields fields,
) {
  return (
    imageId: _validateNonNullablePatchField(
      fields.imageId,
      name: 'imageId',
      transformValue: (value) => validateImageIdValue(value, name: 'imageId'),
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

ImageNodePatchSchemaFields imageNodePatchSchemaFieldsFromValidated(
  ImageNodePatchSchemaFields fields,
) => fields;

TextNodePatchSchemaFields validateTextNodePatchSchemaFields(
  TextNodePatchSchemaFields fields,
) {
  return (
    text: _validateNonNullablePatchField(
      fields.text,
      name: 'text',
      transformValue: (value) => validateTextContentValue(value, name: 'text'),
    ),
    fontSize: _validateNonNullablePatchField(
      fields.fontSize,
      name: 'fontSize',
      transformValue: (value) =>
          validatePositiveFiniteDoubleValue(value, name: 'fontSize'),
    ),
    color: _validateNonNullablePatchField(
      fields.color,
      name: 'color',
      transformValue: (value) => value,
    ),
    align: _validateNonNullablePatchField(
      fields.align,
      name: 'align',
      transformValue: (value) => value,
    ),
    textDirection: _validateNonNullablePatchField(
      fields.textDirection,
      name: 'textDirection',
      transformValue: (value) => value,
    ),
    isBold: _validateNonNullablePatchField(
      fields.isBold,
      name: 'isBold',
      transformValue: (value) => value,
    ),
    isItalic: _validateNonNullablePatchField(
      fields.isItalic,
      name: 'isItalic',
      transformValue: (value) => value,
    ),
    isUnderline: _validateNonNullablePatchField(
      fields.isUnderline,
      name: 'isUnderline',
      transformValue: (value) => value,
    ),
    fontFamily: _validateNullablePatchField(
      fields.fontFamily,
      transformValue: (value) =>
          validateFontFamilyValue(value, name: 'fontFamily'),
    ),
    maxWidth: _validateNullablePatchField(
      fields.maxWidth,
      transformValue: (value) =>
          validatePositiveFiniteDoubleValue(value, name: 'maxWidth'),
    ),
    lineHeight: _validateNullablePatchField(
      fields.lineHeight,
      transformValue: (value) =>
          validatePositiveFiniteDoubleValue(value, name: 'lineHeight'),
    ),
  );
}

TextNodePatchSchemaFields textNodePatchSchemaFieldsFromValidated(
  TextNodePatchSchemaFields fields,
) => fields;

StrokeNodePatchSchemaFields validateStrokeNodePatchSchemaFields(
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
          validatePositiveFiniteDoubleValue(value, name: 'thickness'),
    ),
    color: _validateNonNullablePatchField(
      fields.color,
      name: 'color',
      transformValue: (value) => value,
    ),
  );
}

StrokeNodePatchSchemaFields strokeNodePatchSchemaFieldsFromValidated(
  StrokeNodePatchSchemaFields fields,
) {
  return (
    points: snapshotOffsetListPatchField(fields.points),
    thickness: fields.thickness,
    color: fields.color,
  );
}

LineNodePatchSchemaFields validateLineNodePatchSchemaFields(
  LineNodePatchSchemaFields fields,
) {
  return (
    start: _validateNonNullablePatchField(
      fields.start,
      name: 'start',
      transformValue: (value) =>
          validateFiniteOffsetValue(value, name: 'start'),
    ),
    end: _validateNonNullablePatchField(
      fields.end,
      name: 'end',
      transformValue: (value) => validateFiniteOffsetValue(value, name: 'end'),
    ),
    thickness: _validateNonNullablePatchField(
      fields.thickness,
      name: 'thickness',
      transformValue: (value) =>
          validatePositiveFiniteDoubleValue(value, name: 'thickness'),
    ),
    color: _validateNonNullablePatchField(
      fields.color,
      name: 'color',
      transformValue: (value) => value,
    ),
  );
}

LineNodePatchSchemaFields lineNodePatchSchemaFieldsFromValidated(
  LineNodePatchSchemaFields fields,
) => fields;

RectNodePatchSchemaFields validateRectNodePatchSchemaFields(
  RectNodePatchSchemaFields fields,
) {
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
          validateNonNegativeFiniteDoubleValue(value, name: 'strokeWidth'),
    ),
  );
}

RectNodePatchSchemaFields rectNodePatchSchemaFieldsFromValidated(
  RectNodePatchSchemaFields fields,
) => fields;

PathNodePatchSchemaFields validatePathNodePatchSchemaFields(
  PathNodePatchSchemaFields fields,
) {
  return (
    svgPathData: _validateNonNullablePatchField(
      fields.svgPathData,
      name: 'svgPathData',
      transformValue: (value) =>
          validateSvgPathDataValue(value, name: 'svgPathData'),
    ),
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: _validateNonNullablePatchField(
      fields.strokeWidth,
      name: 'strokeWidth',
      transformValue: (value) =>
          validateNonNegativeFiniteDoubleValue(value, name: 'strokeWidth'),
    ),
    fillRule: _validateNonNullablePatchField(
      fields.fillRule,
      name: 'fillRule',
      transformValue: (value) => value,
    ),
  );
}

PathNodePatchSchemaFields pathNodePatchSchemaFieldsFromValidated(
  PathNodePatchSchemaFields fields,
) => fields;

PatchField<List<Offset>> snapshotOffsetListPatchField(
  PatchField<List<Offset>> patch,
) {
  if (patch.isAbsent) return patch;
  return PatchField<List<Offset>>.value(canonicalOwnedOffsetList(patch.value));
}

PatchField<T> _validateNonNullablePatchField<T>(
  PatchField<T> patch, {
  required String name,
  required T Function(T value) transformValue,
}) {
  if (patch.isAbsent) return patch;
  if (patch.isNullValue) {
    throw ArgumentError.value(
      null,
      name,
      'PatchField.nullValue() is invalid for non-nullable field.',
    );
  }
  final value = transformValue(patch.value);
  return PatchField<T>.value(value);
}

PatchField<T?> _validateNullablePatchField<T>(
  PatchField<T?> patch, {
  required T Function(T value) transformValue,
}) {
  if (patch.isAbsent || patch.isNullValue) return patch;
  final value = transformValue(patch.value as T);
  return PatchField<T?>.value(value);
}
