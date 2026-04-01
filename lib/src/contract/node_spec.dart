import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'internal/node_boundary_schema.dart';
import 'internal/node_spec_backing.dart';
import 'path_fill_rule.dart';
import 'snapshot.dart' hide PathFillRule;
import 'transform2d.dart';

/// Immutable node creation spec for transactional write APIs.
sealed class NodeSpec {
  NodeSpec._materialized(this._backing);

  final NodeSpecBacking _backing;

  @internal
  NodeSpecBacking get internalBacking => _backing;

  NodeId? get id => _backing.id;
  Transform2D get transform => _backing.transform;
  double get opacity => _backing.opacity;
  double get hitPadding => _backing.hitPadding;
  bool get isVisible => _backing.isVisible;
  bool get isSelectable => _backing.isSelectable;
  bool get isLocked => _backing.isLocked;
  bool get isDeletable => _backing.isDeletable;
  bool get isTransformable => _backing.isTransformable;
}

class ImageNodeSpec extends NodeSpec {
  ImageNodeSpec({
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
  }) : this._validated(
         common: validateSpecCommonSchemaFields((
           id: id,
           transform: transform,
           opacity: opacity,
           hitPadding: hitPadding,
           isVisible: isVisible,
           isSelectable: isSelectable,
           isLocked: isLocked,
           isDeletable: isDeletable,
           isTransformable: isTransformable,
         )),
         fields: validateImageNodeSchemaFields((
           imageId: imageId,
           size: size,
           naturalSize: naturalSize,
         )),
       );

  ImageNodeSpec._validated({
    required NodeSpecCommonSchemaFields common,
    required ImageNodeSchemaFields fields,
  }) : this._materialized(
         imageNodeSpecBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory ImageNodeSpec.materialize(ImageNodeSpecBacking backing) =
      ImageNodeSpec._materialized;

  ImageNodeSpec._materialized(super._backing) : super._materialized();

  ImageNodeSpecBacking get _imageBacking =>
      internalBacking as ImageNodeSpecBacking;

  String get imageId => _imageBacking.imageId;
  Size get size => _imageBacking.size;
  Size? get naturalSize => _imageBacking.naturalSize;
}

class TextNodeSpec extends NodeSpec {
  TextNodeSpec({
    NodeId? id,
    required String text,
    double fontSize = 24,
    required Color color,
    TextAlign align = TextAlign.left,
    required TextDirection textDirection,
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
  }) : this._validated(
         common: validateSpecCommonSchemaFields((
           id: id,
           transform: transform,
           opacity: opacity,
           hitPadding: hitPadding,
           isVisible: isVisible,
           isSelectable: isSelectable,
           isLocked: isLocked,
           isDeletable: isDeletable,
           isTransformable: isTransformable,
         )),
         fields: validateTextNodeSpecSchemaFields((
           text: text,
           fontSize: fontSize,
           color: color,
           align: align,
           textDirection: textDirection,
           isBold: isBold,
           isItalic: isItalic,
           isUnderline: isUnderline,
           fontFamily: fontFamily,
           maxWidth: maxWidth,
           lineHeight: lineHeight,
         )),
       );

  TextNodeSpec._validated({
    required NodeSpecCommonSchemaFields common,
    required TextNodeSpecSchemaFields fields,
  }) : this._materialized(
         textNodeSpecBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory TextNodeSpec.materialize(TextNodeSpecBacking backing) =
      TextNodeSpec._materialized;

  TextNodeSpec._materialized(super._backing) : super._materialized();

  TextNodeSpecBacking get _textBacking =>
      internalBacking as TextNodeSpecBacking;

  String get text => _textBacking.text;
  double get fontSize => _textBacking.fontSize;
  Color get color => _textBacking.color;
  TextAlign get align => _textBacking.align;
  TextDirection get textDirection => _textBacking.textDirection;
  bool get isBold => _textBacking.isBold;
  bool get isItalic => _textBacking.isItalic;
  bool get isUnderline => _textBacking.isUnderline;
  String? get fontFamily => _textBacking.fontFamily;
  double? get maxWidth => _textBacking.maxWidth;
  double? get lineHeight => _textBacking.lineHeight;
}

class StrokeNodeSpec extends NodeSpec {
  StrokeNodeSpec({
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
  }) : this._validated(
         common: validateSpecCommonSchemaFields((
           id: id,
           transform: transform,
           opacity: opacity,
           hitPadding: hitPadding,
           isVisible: isVisible,
           isSelectable: isSelectable,
           isLocked: isLocked,
           isDeletable: isDeletable,
           isTransformable: isTransformable,
         )),
         fields: validateStrokeNodeSpecSchemaFields((
           points: points,
           thickness: thickness,
           color: color,
         )),
       );

  StrokeNodeSpec._validated({
    required NodeSpecCommonSchemaFields common,
    required StrokeNodeSpecSchemaInput fields,
  }) : this._materialized(
         strokeNodeSpecBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory StrokeNodeSpec.materialize(StrokeNodeSpecBacking backing) =
      StrokeNodeSpec._materialized;

  StrokeNodeSpec._materialized(super._backing) : super._materialized();

  StrokeNodeSpecBacking get _strokeBacking =>
      internalBacking as StrokeNodeSpecBacking;

  List<Offset> get points => _strokeBacking.points;
  double get thickness => _strokeBacking.thickness;
  Color get color => _strokeBacking.color;
}

class LineNodeSpec extends NodeSpec {
  LineNodeSpec({
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
  }) : this._validated(
         common: validateSpecCommonSchemaFields((
           id: id,
           transform: transform,
           opacity: opacity,
           hitPadding: hitPadding,
           isVisible: isVisible,
           isSelectable: isSelectable,
           isLocked: isLocked,
           isDeletable: isDeletable,
           isTransformable: isTransformable,
         )),
         fields: validateLineNodeSchemaFields((
           start: start,
           end: end,
           thickness: thickness,
           color: color,
         )),
       );

  LineNodeSpec._validated({
    required NodeSpecCommonSchemaFields common,
    required LineNodeSchemaFields fields,
  }) : this._materialized(
         lineNodeSpecBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory LineNodeSpec.materialize(LineNodeSpecBacking backing) =
      LineNodeSpec._materialized;

  LineNodeSpec._materialized(super._backing) : super._materialized();

  LineNodeSpecBacking get _lineBacking =>
      internalBacking as LineNodeSpecBacking;

  Offset get start => _lineBacking.start;
  Offset get end => _lineBacking.end;
  double get thickness => _lineBacking.thickness;
  Color get color => _lineBacking.color;
}

class RectNodeSpec extends NodeSpec {
  RectNodeSpec({
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
  }) : this._validated(
         common: validateSpecCommonSchemaFields((
           id: id,
           transform: transform,
           opacity: opacity,
           hitPadding: hitPadding,
           isVisible: isVisible,
           isSelectable: isSelectable,
           isLocked: isLocked,
           isDeletable: isDeletable,
           isTransformable: isTransformable,
         )),
         fields: validateRectNodeSchemaFields((
           size: size,
           fillColor: fillColor,
           strokeColor: strokeColor,
           strokeWidth: strokeWidth,
         )),
       );

  RectNodeSpec._validated({
    required NodeSpecCommonSchemaFields common,
    required RectNodeSchemaFields fields,
  }) : this._materialized(
         rectNodeSpecBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory RectNodeSpec.materialize(RectNodeSpecBacking backing) =
      RectNodeSpec._materialized;

  RectNodeSpec._materialized(super._backing) : super._materialized();

  RectNodeSpecBacking get _rectBacking =>
      internalBacking as RectNodeSpecBacking;

  Size get size => _rectBacking.size;
  Color? get fillColor => _rectBacking.fillColor;
  Color? get strokeColor => _rectBacking.strokeColor;
  double get strokeWidth => _rectBacking.strokeWidth;
}

class PathNodeSpec extends NodeSpec {
  PathNodeSpec({
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
  }) : this._validated(
         common: validateSpecCommonSchemaFields((
           id: id,
           transform: transform,
           opacity: opacity,
           hitPadding: hitPadding,
           isVisible: isVisible,
           isSelectable: isSelectable,
           isLocked: isLocked,
           isDeletable: isDeletable,
           isTransformable: isTransformable,
         )),
         fields: validatePathNodeSchemaFields((
           svgPathData: svgPathData,
           fillColor: fillColor,
           strokeColor: strokeColor,
           strokeWidth: strokeWidth,
           fillRule: fillRule,
         )),
       );

  PathNodeSpec._validated({
    required NodeSpecCommonSchemaFields common,
    required PathNodeSchemaFields fields,
  }) : this._materialized(
         pathNodeSpecBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory PathNodeSpec.materialize(PathNodeSpecBacking backing) =
      PathNodeSpec._materialized;

  PathNodeSpec._materialized(super._backing) : super._materialized();

  PathNodeSpecBacking get _pathBacking =>
      internalBacking as PathNodeSpecBacking;

  String get svgPathData => _pathBacking.svgPathData;
  Color? get fillColor => _pathBacking.fillColor;
  Color? get strokeColor => _pathBacking.strokeColor;
  double get strokeWidth => _pathBacking.strokeWidth;
  PathFillRule get fillRule => _pathBacking.fillRule;
}
