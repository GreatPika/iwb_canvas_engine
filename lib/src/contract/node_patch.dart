import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'owned_collections.dart';
import 'patch_field.dart';
import 'path_fill_rule.dart';
import 'snapshot.dart' hide PathFillRule;
import 'transform2d.dart';
import 'validated/finite_offset_value.dart';
import 'validated/font_family_value.dart';
import 'validated/image_id_value.dart';
import 'validated/node_id_value.dart';
import 'validated/non_negative_finite_double_value.dart';
import 'validated/opacity_value.dart';
import 'validated/positive_finite_double_value.dart';
import 'validated/svg_path_data_value.dart';
import 'validated/text_content_value.dart';

part 'internal/node_patch_fast_path.part.dart';

/// Patch for common node fields shared by all node variants.
class CommonNodePatch {
  factory CommonNodePatch({
    PatchField<Transform2D> transform = const PatchField<Transform2D>.absent(),
    PatchField<double> opacity = const PatchField<double>.absent(),
    PatchField<double> hitPadding = const PatchField<double>.absent(),
    PatchField<bool> isVisible = const PatchField<bool>.absent(),
    PatchField<bool> isSelectable = const PatchField<bool>.absent(),
    PatchField<bool> isLocked = const PatchField<bool>.absent(),
    PatchField<bool> isDeletable = const PatchField<bool>.absent(),
    PatchField<bool> isTransformable = const PatchField<bool>.absent(),
  }) {
    return CommonNodePatch._internal(
      transform: _validateNonNullablePatchField(
        transform,
        name: 'transform',
        transformValue: (value) =>
            _validateFiniteTransform2D(value, name: 'transform'),
      ),
      opacity: _validateNonNullablePatchField(
        opacity,
        name: 'opacity',
        transformValue: (value) =>
            OpacityValue.of(value, name: 'opacity').value,
      ),
      hitPadding: _validateNonNullablePatchField(
        hitPadding,
        name: 'hitPadding',
        transformValue: (value) =>
            NonNegativeFiniteDoubleValue.of(value, name: 'hitPadding').value,
      ),
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
  }

  const CommonNodePatch._internal({
    this.transform = const PatchField<Transform2D>.absent(),
    this.opacity = const PatchField<double>.absent(),
    this.hitPadding = const PatchField<double>.absent(),
    this.isVisible = const PatchField<bool>.absent(),
    this.isSelectable = const PatchField<bool>.absent(),
    this.isLocked = const PatchField<bool>.absent(),
    this.isDeletable = const PatchField<bool>.absent(),
    this.isTransformable = const PatchField<bool>.absent(),
  });

  final PatchField<Transform2D> transform;
  final PatchField<double> opacity;
  final PatchField<double> hitPadding;
  final PatchField<bool> isVisible;
  final PatchField<bool> isSelectable;
  final PatchField<bool> isLocked;
  final PatchField<bool> isDeletable;
  final PatchField<bool> isTransformable;
}

/// Partial node update request for transactional write APIs.
sealed class NodePatch {
  const NodePatch._internal({required this.id, required this.common});

  final NodeId id;
  final CommonNodePatch common;
}

class ImageNodePatch extends NodePatch {
  factory ImageNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<String> imageId = const PatchField<String>.absent(),
    PatchField<Size> size = const PatchField<Size>.absent(),
    PatchField<Size?> naturalSize = const PatchField<Size?>.absent(),
  }) {
    return ImageNodePatch._internal(
      id: NodeIdValue.of(id, name: 'id').value,
      common: common ?? CommonNodePatch(),
      imageId: _validateNonNullablePatchField(
        imageId,
        name: 'imageId',
        transformValue: (value) =>
            ImageIdValue.of(value, name: 'imageId').value,
      ),
      size: _validateNonNullablePatchField(
        size,
        name: 'size',
        transformValue: (value) =>
            _validateNonNegativeSize(value, name: 'size'),
      ),
      naturalSize: _validateNullablePatchField(
        naturalSize,
        name: 'naturalSize',
        transformValue: (value) =>
            _validateNonNegativeSize(value, name: 'naturalSize'),
      ),
    );
  }

  const ImageNodePatch._internal({
    required super.id,
    required super.common,
    this.imageId = const PatchField<String>.absent(),
    this.size = const PatchField<Size>.absent(),
    this.naturalSize = const PatchField<Size?>.absent(),
  }) : super._internal();

  final PatchField<String> imageId;
  final PatchField<Size> size;
  final PatchField<Size?> naturalSize;
}

class TextNodePatch extends NodePatch {
  factory TextNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<String> text = const PatchField<String>.absent(),
    PatchField<double> fontSize = const PatchField<double>.absent(),
    PatchField<Color> color = const PatchField<Color>.absent(),
    PatchField<TextAlign> align = const PatchField<TextAlign>.absent(),
    PatchField<bool> isBold = const PatchField<bool>.absent(),
    PatchField<bool> isItalic = const PatchField<bool>.absent(),
    PatchField<bool> isUnderline = const PatchField<bool>.absent(),
    PatchField<String?> fontFamily = const PatchField<String?>.absent(),
    PatchField<double?> maxWidth = const PatchField<double?>.absent(),
    PatchField<double?> lineHeight = const PatchField<double?>.absent(),
  }) {
    return TextNodePatch._internal(
      id: NodeIdValue.of(id, name: 'id').value,
      common: common ?? CommonNodePatch(),
      text: _validateNonNullablePatchField(
        text,
        name: 'text',
        transformValue: (value) =>
            TextContentValue.of(value, name: 'text').value,
      ),
      fontSize: _validateNonNullablePatchField(
        fontSize,
        name: 'fontSize',
        transformValue: (value) =>
            PositiveFiniteDoubleValue.of(value, name: 'fontSize').value,
      ),
      color: color,
      align: align,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      fontFamily: _validateNullablePatchField(
        fontFamily,
        name: 'fontFamily',
        transformValue: (value) =>
            FontFamilyValue.of(value, name: 'fontFamily').value,
      ),
      maxWidth: _validateNullablePatchField(
        maxWidth,
        name: 'maxWidth',
        transformValue: (value) =>
            PositiveFiniteDoubleValue.of(value, name: 'maxWidth').value,
      ),
      lineHeight: _validateNullablePatchField(
        lineHeight,
        name: 'lineHeight',
        transformValue: (value) =>
            PositiveFiniteDoubleValue.of(value, name: 'lineHeight').value,
      ),
    );
  }

  const TextNodePatch._internal({
    required super.id,
    required super.common,
    this.text = const PatchField<String>.absent(),
    this.fontSize = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
    this.align = const PatchField<TextAlign>.absent(),
    this.isBold = const PatchField<bool>.absent(),
    this.isItalic = const PatchField<bool>.absent(),
    this.isUnderline = const PatchField<bool>.absent(),
    this.fontFamily = const PatchField<String?>.absent(),
    this.maxWidth = const PatchField<double?>.absent(),
    this.lineHeight = const PatchField<double?>.absent(),
  }) : super._internal();

  final PatchField<String> text;
  final PatchField<double> fontSize;
  final PatchField<Color> color;
  final PatchField<TextAlign> align;
  final PatchField<bool> isBold;
  final PatchField<bool> isItalic;
  final PatchField<bool> isUnderline;
  final PatchField<String?> fontFamily;
  final PatchField<double?> maxWidth;
  final PatchField<double?> lineHeight;
}

class StrokeNodePatch extends NodePatch {
  factory StrokeNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<List<Offset>> points = const PatchField<List<Offset>>.absent(),
    PatchField<double> thickness = const PatchField<double>.absent(),
    PatchField<Color> color = const PatchField<Color>.absent(),
  }) {
    return StrokeNodePatch._internal(
      id: NodeIdValue.of(id, name: 'id').value,
      common: common ?? CommonNodePatch(),
      points: _validateNonNullablePatchField(
        points,
        name: 'points',
        transformValue: (value) =>
            _validateFiniteOffsetList(value, name: 'points'),
      ),
      thickness: _validateNonNullablePatchField(
        thickness,
        name: 'thickness',
        transformValue: (value) =>
            PositiveFiniteDoubleValue.of(value, name: 'thickness').value,
      ),
      color: color,
    );
  }

  StrokeNodePatch._internal({
    required super.id,
    required super.common,
    PatchField<List<Offset>> points = const PatchField<List<Offset>>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  }) : points = _snapshotOffsetListPatchField(points),
       super._internal();

  final PatchField<List<Offset>> points;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

class LineNodePatch extends NodePatch {
  factory LineNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<Offset> start = const PatchField<Offset>.absent(),
    PatchField<Offset> end = const PatchField<Offset>.absent(),
    PatchField<double> thickness = const PatchField<double>.absent(),
    PatchField<Color> color = const PatchField<Color>.absent(),
  }) {
    return LineNodePatch._internal(
      id: NodeIdValue.of(id, name: 'id').value,
      common: common ?? CommonNodePatch(),
      start: _validateNonNullablePatchField(
        start,
        name: 'start',
        transformValue: (value) =>
            FiniteOffsetValue.of(value, name: 'start').value,
      ),
      end: _validateNonNullablePatchField(
        end,
        name: 'end',
        transformValue: (value) =>
            FiniteOffsetValue.of(value, name: 'end').value,
      ),
      thickness: _validateNonNullablePatchField(
        thickness,
        name: 'thickness',
        transformValue: (value) =>
            PositiveFiniteDoubleValue.of(value, name: 'thickness').value,
      ),
      color: color,
    );
  }

  const LineNodePatch._internal({
    required super.id,
    required super.common,
    this.start = const PatchField<Offset>.absent(),
    this.end = const PatchField<Offset>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  }) : super._internal();

  final PatchField<Offset> start;
  final PatchField<Offset> end;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

class RectNodePatch extends NodePatch {
  factory RectNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<Size> size = const PatchField<Size>.absent(),
    PatchField<Color?> fillColor = const PatchField<Color?>.absent(),
    PatchField<Color?> strokeColor = const PatchField<Color?>.absent(),
    PatchField<double> strokeWidth = const PatchField<double>.absent(),
  }) {
    return RectNodePatch._internal(
      id: NodeIdValue.of(id, name: 'id').value,
      common: common ?? CommonNodePatch(),
      size: _validateNonNullablePatchField(
        size,
        name: 'size',
        transformValue: (value) =>
            _validateNonNegativeSize(value, name: 'size'),
      ),
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: _validateNonNullablePatchField(
        strokeWidth,
        name: 'strokeWidth',
        transformValue: (value) =>
            NonNegativeFiniteDoubleValue.of(value, name: 'strokeWidth').value,
      ),
    );
  }

  const RectNodePatch._internal({
    required super.id,
    required super.common,
    this.size = const PatchField<Size>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
  }) : super._internal();

  final PatchField<Size> size;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
}

class PathNodePatch extends NodePatch {
  factory PathNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<String> svgPathData = const PatchField<String>.absent(),
    PatchField<Color?> fillColor = const PatchField<Color?>.absent(),
    PatchField<Color?> strokeColor = const PatchField<Color?>.absent(),
    PatchField<double> strokeWidth = const PatchField<double>.absent(),
    PatchField<PathFillRule> fillRule = const PatchField<PathFillRule>.absent(),
  }) {
    return PathNodePatch._internal(
      id: NodeIdValue.of(id, name: 'id').value,
      common: common ?? CommonNodePatch(),
      svgPathData: _validateNonNullablePatchField(
        svgPathData,
        name: 'svgPathData',
        transformValue: (value) =>
            SvgPathDataValue.of(value, name: 'svgPathData').value,
      ),
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: _validateNonNullablePatchField(
        strokeWidth,
        name: 'strokeWidth',
        transformValue: (value) =>
            NonNegativeFiniteDoubleValue.of(value, name: 'strokeWidth').value,
      ),
      fillRule: fillRule,
    );
  }

  const PathNodePatch._internal({
    required super.id,
    required super.common,
    this.svgPathData = const PatchField<String>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
    this.fillRule = const PatchField<PathFillRule>.absent(),
  }) : super._internal();

  final PatchField<String> svgPathData;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
  final PatchField<PathFillRule> fillRule;
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
  required String name,
  required T Function(T value) transformValue,
}) {
  if (patch.isAbsent || patch.isNullValue) return patch;
  final rawValue = patch.value;
  if (rawValue == null) {
    return PatchField<T?>.value(null);
  }
  final value = transformValue(rawValue);
  return PatchField<T?>.value(value);
}

Transform2D _validateFiniteTransform2D(
  Transform2D value, {
  required String name,
}) {
  _requireFiniteDouble(value.a, name: '$name.a');
  _requireFiniteDouble(value.b, name: '$name.b');
  _requireFiniteDouble(value.c, name: '$name.c');
  _requireFiniteDouble(value.d, name: '$name.d');
  _requireFiniteDouble(value.tx, name: '$name.tx');
  _requireFiniteDouble(value.ty, name: '$name.ty');
  if (value.invert() == null) {
    throw ArgumentError.value(
      value.toJsonMap(),
      name,
      'Must be invertible (non-singular).',
    );
  }
  return value;
}

void _requireFiniteDouble(double value, {required String name}) {
  if (value.isFinite) return;
  throw ArgumentError.value(value, name, 'Must be finite.');
}

Size _validateNonNegativeSize(Size value, {required String name}) {
  return Size(
    NonNegativeFiniteDoubleValue.of(value.width, name: '$name.width').value,
    NonNegativeFiniteDoubleValue.of(value.height, name: '$name.height').value,
  );
}

OwnedList<Offset> _validateFiniteOffsetList(
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

PatchField<List<Offset>> _snapshotOffsetListPatchField(
  PatchField<List<Offset>> patch,
) {
  if (patch.isAbsent) return patch;
  final points = patch.value;
  return PatchField<List<Offset>>.value(OwnedList<Offset>.of(points));
}
