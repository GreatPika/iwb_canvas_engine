import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'internal/node_boundary_schema.dart';
import 'owned_collections.dart';
import 'path_fill_rule.dart';
import 'snapshot.dart' hide PathFillRule;
import 'transform2d.dart';

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
    final common = NodeBoundarySchema.validateSpecCommon((
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    ));
    final fields = NodeBoundarySchema.validateImageFields((
      imageId: imageId,
      size: size,
      naturalSize: naturalSize,
    ));
    return _imageNodeSpecFromSchema(common: common, fields: fields);
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
    final common = NodeBoundarySchema.validateSpecCommon((
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    ));
    final fields = NodeBoundarySchema.validateTextSpecFields((
      text: text,
      fontSize: fontSize,
      color: color,
      align: align,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      fontFamily: fontFamily,
      maxWidth: maxWidth,
      lineHeight: lineHeight,
    ));
    return _textNodeSpecFromSchema(common: common, fields: fields);
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
    final common = NodeBoundarySchema.validateSpecCommon((
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    ));
    final fields = NodeBoundarySchema.validateStrokeSpecFields((
      points: points,
      thickness: thickness,
      color: color,
    ));
    return _strokeNodeSpecFromSchema(common: common, fields: fields);
  }

  StrokeNodeSpec._internal({
    super.id,
    required Iterable<Offset> points,
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
  }) : _points = OwnedList<Offset>.of(points),
       super._internal();

  final OwnedList<Offset> _points;
  List<Offset> get points => _points;
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
    final common = NodeBoundarySchema.validateSpecCommon((
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    ));
    final fields = NodeBoundarySchema.validateLineFields((
      start: start,
      end: end,
      thickness: thickness,
      color: color,
    ));
    return _lineNodeSpecFromSchema(common: common, fields: fields);
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
    final common = NodeBoundarySchema.validateSpecCommon((
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    ));
    final fields = NodeBoundarySchema.validateRectFields((
      size: size,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
    ));
    return _rectNodeSpecFromSchema(common: common, fields: fields);
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
    final common = NodeBoundarySchema.validateSpecCommon((
      id: id,
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    ));
    final fields = NodeBoundarySchema.validatePathFields((
      svgPathData: svgPathData,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      fillRule: fillRule,
    ));
    return _pathNodeSpecFromSchema(common: common, fields: fields);
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

ImageNodeSpec _imageNodeSpecFromSchema({
  required NodeSpecCommonSchemaFields common,
  required ImageNodeSchemaFields fields,
}) {
  return ImageNodeSpec._internal(
    id: common.id,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
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

TextNodeSpec _textNodeSpecFromSchema({
  required NodeSpecCommonSchemaFields common,
  required TextNodeSpecSchemaFields fields,
}) {
  return TextNodeSpec._internal(
    id: common.id,
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

StrokeNodeSpec _strokeNodeSpecFromSchema({
  required NodeSpecCommonSchemaFields common,
  required StrokeNodeSpecSchemaFields fields,
}) {
  return StrokeNodeSpec._internal(
    id: common.id,
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
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

LineNodeSpec _lineNodeSpecFromSchema({
  required NodeSpecCommonSchemaFields common,
  required LineNodeSchemaFields fields,
}) {
  return LineNodeSpec._internal(
    id: common.id,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
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

RectNodeSpec _rectNodeSpecFromSchema({
  required NodeSpecCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return RectNodeSpec._internal(
    id: common.id,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
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

PathNodeSpec _pathNodeSpecFromSchema({
  required NodeSpecCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return PathNodeSpec._internal(
    id: common.id,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
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
