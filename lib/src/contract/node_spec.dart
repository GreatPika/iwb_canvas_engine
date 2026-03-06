import 'dart:ui';

import 'package:flutter/foundation.dart';

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
import 'validated/validated_value_support.dart';

part 'internal/node_spec_fast_path.part.dart';

/// Immutable node creation spec for transactional write APIs.
sealed class NodeSpec {
  const NodeSpec._internal({
    this.id,
    this.transform = Transform2D.identity,
    this.opacity = 1,
    this.hitPadding = 0,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
  });

  final NodeId? id;
  final Transform2D transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
}

class ImageNodeSpec extends NodeSpec {
  factory ImageNodeSpec({
    NodeId? id,
    required String imageId,
    required Size size,
    Size? naturalSize,
    Transform2D transform = Transform2D.identity,
    double opacity = 1,
    double hitPadding = 0,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final common = _validateNodeSpecCommonFields(
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
    return ImageNodeSpec._internal(
      id: common.id,
      imageId: ImageIdValue.of(imageId, name: 'imageId').value,
      size: _validateNonNegativeSize(size, name: 'size'),
      naturalSize: naturalSize == null
          ? null
          : _validateNonNegativeSize(naturalSize, name: 'naturalSize'),
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
    );
  }

  ImageNodeSpec._internal({
    super.id,
    required this.imageId,
    required this.size,
    this.naturalSize,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super._internal();

  final String imageId;
  final Size size;
  final Size? naturalSize;
}

class TextNodeSpec extends NodeSpec {
  factory TextNodeSpec({
    NodeId? id,
    required String text,
    double fontSize = 24,
    required Color color,
    TextAlign align = TextAlign.left,
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    String? fontFamily,
    double? maxWidth,
    double? lineHeight,
    Transform2D transform = Transform2D.identity,
    double opacity = 1,
    double hitPadding = 0,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final common = _validateNodeSpecCommonFields(
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
    return TextNodeSpec._internal(
      id: common.id,
      text: TextContentValue.of(text, name: 'text').value,
      fontSize: PositiveFiniteDoubleValue.of(fontSize, name: 'fontSize').value,
      color: color,
      align: align,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      fontFamily: fontFamily == null
          ? null
          : FontFamilyValue.of(fontFamily, name: 'fontFamily').value,
      maxWidth: maxWidth == null
          ? null
          : PositiveFiniteDoubleValue.of(maxWidth, name: 'maxWidth').value,
      lineHeight: lineHeight == null
          ? null
          : PositiveFiniteDoubleValue.of(lineHeight, name: 'lineHeight').value,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
    );
  }

  TextNodeSpec._internal({
    super.id,
    required this.text,
    this.fontSize = 24,
    required this.color,
    this.align = TextAlign.left,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super._internal();

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}

class StrokeNodeSpec extends NodeSpec {
  factory StrokeNodeSpec({
    NodeId? id,
    required List<Offset> points,
    required double thickness,
    required Color color,
    Transform2D transform = Transform2D.identity,
    double opacity = 1,
    double hitPadding = 0,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final common = _validateNodeSpecCommonFields(
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
    return StrokeNodeSpec._internal(
      id: common.id,
      points: _validateFiniteOffsetList(points, name: 'points'),
      thickness: PositiveFiniteDoubleValue.of(
        thickness,
        name: 'thickness',
      ).value,
      color: color,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
    );
  }

  StrokeNodeSpec._internal({
    super.id,
    required List<Offset> points,
    required this.thickness,
    required this.color,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : points = List<Offset>.unmodifiable(points),
       super._internal();

  final List<Offset> points;
  final double thickness;
  final Color color;
}

class LineNodeSpec extends NodeSpec {
  factory LineNodeSpec({
    NodeId? id,
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    Transform2D transform = Transform2D.identity,
    double opacity = 1,
    double hitPadding = 0,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final common = _validateNodeSpecCommonFields(
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
    return LineNodeSpec._internal(
      id: common.id,
      start: FiniteOffsetValue.of(start, name: 'start').value,
      end: FiniteOffsetValue.of(end, name: 'end').value,
      thickness: PositiveFiniteDoubleValue.of(
        thickness,
        name: 'thickness',
      ).value,
      color: color,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
    );
  }

  LineNodeSpec._internal({
    super.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super._internal();

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
}

class RectNodeSpec extends NodeSpec {
  factory RectNodeSpec({
    NodeId? id,
    required Size size,
    Color? fillColor,
    Color? strokeColor,
    double strokeWidth = 1,
    Transform2D transform = Transform2D.identity,
    double opacity = 1,
    double hitPadding = 0,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final common = _validateNodeSpecCommonFields(
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
    return RectNodeSpec._internal(
      id: common.id,
      size: _validateNonNegativeSize(size, name: 'size'),
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: NonNegativeFiniteDoubleValue.of(
        strokeWidth,
        name: 'strokeWidth',
      ).value,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
    );
  }

  RectNodeSpec._internal({
    super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super._internal();

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

class PathNodeSpec extends NodeSpec {
  factory PathNodeSpec({
    NodeId? id,
    required String svgPathData,
    Color? fillColor,
    Color? strokeColor,
    double strokeWidth = 1,
    PathFillRule fillRule = PathFillRule.nonZero,
    Transform2D transform = Transform2D.identity,
    double opacity = 1,
    double hitPadding = 0,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final common = _validateNodeSpecCommonFields(
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
    return PathNodeSpec._internal(
      id: common.id,
      svgPathData: SvgPathDataValue.of(svgPathData, name: 'svgPathData').value,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: NonNegativeFiniteDoubleValue.of(
        strokeWidth,
        name: 'strokeWidth',
      ).value,
      fillRule: fillRule,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
    );
  }

  PathNodeSpec._internal({
    super.id,
    required this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    this.fillRule = PathFillRule.nonZero,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super._internal();

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final PathFillRule fillRule;
}

class _ValidatedNodeSpecCommonFields {
  const _ValidatedNodeSpecCommonFields({
    required this.id,
    required this.transform,
    required this.opacity,
    required this.hitPadding,
    required this.isVisible,
    required this.isSelectable,
    required this.isLocked,
    required this.isDeletable,
    required this.isTransformable,
  });

  final NodeId? id;
  final Transform2D transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
}

_ValidatedNodeSpecCommonFields _validateNodeSpecCommonFields({
  required NodeId? id,
  required Transform2D transform,
  required double opacity,
  required double hitPadding,
  required bool isVisible,
  required bool isSelectable,
  required bool isLocked,
  required bool isDeletable,
  required bool isTransformable,
}) {
  return _ValidatedNodeSpecCommonFields(
    id: id == null ? null : NodeIdValue.of(id, name: 'id').value,
    transform: _validateFiniteTransform2D(transform, name: 'transform'),
    opacity: OpacityValue.of(opacity, name: 'opacity').value,
    hitPadding: NonNegativeFiniteDoubleValue.of(
      hitPadding,
      name: 'hitPadding',
    ).value,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

Transform2D _validateFiniteTransform2D(
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

Size _validateNonNegativeSize(Size value, {required String name}) {
  return Size(
    NonNegativeFiniteDoubleValue.of(value.width, name: '$name.width').value,
    NonNegativeFiniteDoubleValue.of(value.height, name: '$name.height').value,
  );
}

List<Offset> _validateFiniteOffsetList(
  List<Offset> values, {
  required String name,
}) {
  return List<Offset>.unmodifiable(
    List<Offset>.generate(
      values.length,
      (index) =>
          FiniteOffsetValue.of(values[index], name: '$name[$index]').value,
      growable: false,
    ),
  );
}
