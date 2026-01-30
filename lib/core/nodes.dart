import 'dart:ui';

import 'geometry.dart';

enum NodeType { image, text, stroke, line, rect }

typedef NodeId = String;

abstract class SceneNode {
  SceneNode({
    required this.id,
    required this.type,
    this.rotationDeg = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
  });

  final NodeId id;
  final NodeType type;
  double rotationDeg;
  double scaleX;
  double scaleY;
  double opacity;
  bool isVisible;
  bool isSelectable;
  bool isLocked;
  bool isDeletable;
  bool isTransformable;

  Offset get position;
  set position(Offset value);

  Rect get aabb;
}

class ImageNode extends SceneNode {
  ImageNode({
    required super.id,
    required this.imageId,
    required this.size,
    this.naturalSize,
    super.rotationDeg,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.image);

  String imageId;
  Size size;
  Size? naturalSize;
  Offset _position = Offset.zero;

  @override
  Offset get position => _position;

  @override
  set position(Offset value) => _position = value;

  Rect get _localRect => Rect.fromCenter(
        center: Offset.zero,
        width: size.width,
        height: size.height,
      );

  @override
  Rect get aabb => aabbForTransformedRect(
        localRect: _localRect,
        position: position,
        rotationDeg: rotationDeg,
        scaleX: scaleX,
        scaleY: scaleY,
      );
}

class TextNode extends SceneNode {
  TextNode({
    required super.id,
    required this.text,
    required this.size,
    this.fontSize = 24,
    required this.color,
    this.align = TextAlign.left,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    super.rotationDeg,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.text);

  String text;
  Size size;
  double fontSize;
  Color color;
  TextAlign align;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  String? fontFamily;
  double? maxWidth;
  double? lineHeight;
  Offset _position = Offset.zero;

  @override
  Offset get position => _position;

  @override
  set position(Offset value) => _position = value;

  Rect get _localRect => Rect.fromCenter(
        center: Offset.zero,
        width: size.width,
        height: size.height,
      );

  @override
  Rect get aabb => aabbForTransformedRect(
        localRect: _localRect,
        position: position,
        rotationDeg: rotationDeg,
        scaleX: scaleX,
        scaleY: scaleY,
      );
}

class StrokeNode extends SceneNode {
  StrokeNode({
    required super.id,
    required List<Offset> points,
    required this.thickness,
    required this.color,
    super.rotationDeg,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  })  : points = List<Offset>.from(points),
        super(type: NodeType.stroke);

  final List<Offset> points;
  double thickness;
  Color color;

  @override
  Offset get position {
    if (points.isEmpty) return Offset.zero;
    final bounds = aabbFromPoints(points);
    return bounds.center;
  }

  @override
  set position(Offset value) {
    if (points.isEmpty) return;
    final delta = value - position;
    for (var i = 0; i < points.length; i++) {
      points[i] = points[i] + delta;
    }
  }

  @override
  Rect get aabb {
    if (points.isEmpty) return Rect.zero;
    final bounds = aabbFromPoints(points);
    final inflateBy = thickness / 2;
    return bounds.inflate(inflateBy);
  }
}

class LineNode extends SceneNode {
  LineNode({
    required super.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    super.rotationDeg,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.line);

  Offset start;
  Offset end;
  double thickness;
  Color color;

  @override
  Offset get position => Rect.fromPoints(start, end).center;

  @override
  set position(Offset value) {
    final delta = value - position;
    start = start + delta;
    end = end + delta;
  }

  @override
  Rect get aabb {
    final bounds = Rect.fromPoints(start, end);
    return bounds.inflate(thickness / 2);
  }
}

class RectNode extends SceneNode {
  RectNode({
    required super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    super.rotationDeg,
    super.scaleX,
    super.scaleY,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.rect);

  Size size;
  Color? fillColor;
  Color? strokeColor;
  double strokeWidth;
  Offset _position = Offset.zero;

  @override
  Offset get position => _position;

  @override
  set position(Offset value) => _position = value;

  Rect get _localRect => Rect.fromCenter(
        center: Offset.zero,
        width: size.width,
        height: size.height,
      );

  @override
  Rect get aabb => aabbForTransformedRect(
        localRect: _localRect,
        position: position,
        rotationDeg: rotationDeg,
        scaleX: scaleX,
        scaleY: scaleY,
      );
}
