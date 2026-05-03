import 'dart:ui';

import 'internal/node_boundary_schema.dart';
import 'path_fill_rule.dart';
import 'snapshot.dart' hide PathFillRule;
import 'transform2d.dart';

/// Immutable node creation spec for transactional write APIs.
abstract class NodeSpec {
  const NodeSpec({
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
  }) : imageId = fields.imageId,
       size = fields.size,
       naturalSize = fields.naturalSize,
       super(
         id: common.id,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final String imageId;
  final Size size;
  final Size? naturalSize;
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
  }) : text = fields.text,
       fontSize = fields.fontSize,
       color = fields.color,
       align = fields.align,
       textDirection = fields.textDirection,
       isBold = fields.isBold,
       isItalic = fields.isItalic,
       isUnderline = fields.isUnderline,
       fontFamily = fields.fontFamily,
       maxWidth = fields.maxWidth,
       lineHeight = fields.lineHeight,
       super(
         id: common.id,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection textDirection;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
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
  }) : points = List<Offset>.unmodifiable(List<Offset>.from(fields.points)),
       thickness = fields.thickness,
       color = fields.color,
       super(
         id: common.id,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final List<Offset> points;
  final double thickness;
  final Color color;
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
  }) : start = fields.start,
       end = fields.end,
       thickness = fields.thickness,
       color = fields.color,
       super(
         id: common.id,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
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
  }) : size = fields.size,
       fillColor = fields.fillColor,
       strokeColor = fields.strokeColor,
       strokeWidth = fields.strokeWidth,
       super(
         id: common.id,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
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
  }) : svgPathData = fields.svgPathData,
       fillColor = fields.fillColor,
       strokeColor = fields.strokeColor,
       strokeWidth = fields.strokeWidth,
       fillRule = fields.fillRule,
       super(
         id: common.id,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final PathFillRule fillRule;
}
