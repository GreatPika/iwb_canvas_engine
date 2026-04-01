import 'dart:ui';

import '../contract/ids.dart';
import '../contract/transform2d.dart';
import 'local_bounds_policy.dart';
import 'numeric_tolerance.dart' show kUiEpsilonSquared;
import 'scene_node.dart';

/// Raster image node referenced by [imageId] and drawn at [size].
class ImageNode extends SceneNode {
  ImageNode({
    required super.id,
    required this.imageId,
    required this.size,
    this.naturalSize,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.image);

  /// Creates an image node positioned by its axis-aligned world top-left corner.
  ///
  /// This helper is AABB-based: rotation/shear affects [boundsWorld], so
  /// [topLeftWorld] is intended for UI-like positioning (selection box).
  factory ImageNode.fromTopLeftWorld({
    required NodeId id,
    required String imageId,
    required Size size,
    required Offset topLeftWorld,
    Size? naturalSize,
    double hitPadding = 0,
    double opacity = 1,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    return _BoxNodePlacementOwner.createFromTopLeftWorld(
      size: size,
      topLeftWorld: topLeftWorld,
      create: (transform) => ImageNode(
        id: id,
        imageId: imageId,
        size: size,
        naturalSize: naturalSize,
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      ),
    );
  }

  String imageId;
  Size size;
  Size? naturalSize;

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => _BoxNodePlacementOwner.topLeftWorld(this);
  set topLeftWorld(Offset value) =>
      _BoxNodePlacementOwner.setTopLeftWorld(node: this, value: value);

  @override
  Rect get localBounds => _BoxNodePlacementOwner.localRect(size);
}

/// Text node with derived layout box ([size]) and basic styling.
class TextNode extends SceneNode {
  TextNode({
    required super.id,
    required this.text,
    required this.size,
    this.fontSize = 24,
    required this.color,
    this.align = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.text);

  /// Creates a text node positioned by its axis-aligned world top-left corner.
  ///
  /// This helper is AABB-based: rotation/shear affects [boundsWorld], so
  /// [topLeftWorld] is intended for UI-like positioning (selection box).
  factory TextNode.fromTopLeftWorld({
    required NodeId id,
    required String text,
    required Size size,
    required Offset topLeftWorld,
    double fontSize = 24,
    required Color color,
    TextAlign align = TextAlign.left,
    TextDirection textDirection = TextDirection.ltr,
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    String? fontFamily,
    double? maxWidth,
    double? lineHeight,
    double hitPadding = 0,
    double opacity = 1,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    return _BoxNodePlacementOwner.createFromTopLeftWorld(
      size: size,
      topLeftWorld: topLeftWorld,
      create: (transform) => TextNode(
        id: id,
        text: text,
        size: size,
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
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      ),
    );
  }

  String text;
  Size size;
  double fontSize;
  Color color;
  TextAlign align;
  TextDirection textDirection;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  String? fontFamily;
  double? maxWidth;
  double? lineHeight;

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => _BoxNodePlacementOwner.topLeftWorld(this);
  set topLeftWorld(Offset value) =>
      _BoxNodePlacementOwner.setTopLeftWorld(node: this, value: value);

  @override
  Rect get localBounds => _BoxNodePlacementOwner.localRect(size);
}

/// Box node with optional fill and stroke.
class RectNode extends SceneNode {
  RectNode({
    required super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.rect);

  /// Creates a rect node positioned by its axis-aligned world top-left corner.
  ///
  /// This helper is AABB-based: rotation/shear affects [boundsWorld], so
  /// [topLeftWorld] is intended for UI-like positioning (selection box).
  factory RectNode.fromTopLeftWorld({
    required NodeId id,
    required Size size,
    required Offset topLeftWorld,
    Color? fillColor,
    Color? strokeColor,
    double strokeWidth = 1,
    double hitPadding = 0,
    double opacity = 1,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    return _BoxNodePlacementOwner.createFromTopLeftWorld(
      size: size,
      topLeftWorld: topLeftWorld,
      create: (transform) => RectNode(
        id: id,
        size: size,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      ),
    );
  }

  Size size;
  Color? fillColor;
  Color? strokeColor;
  double strokeWidth;

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => _BoxNodePlacementOwner.topLeftWorld(this);
  set topLeftWorld(Offset value) =>
      _BoxNodePlacementOwner.setTopLeftWorld(node: this, value: value);

  @override
  Rect get localBounds => strokeAwareLocalBounds(
    baseBounds: _BoxNodePlacementOwner.localRect(size),
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  );
}

abstract final class _BoxNodePlacementOwner {
  static T createFromTopLeftWorld<T extends SceneNode>({
    required Size size,
    required Offset topLeftWorld,
    required T Function(Transform2D transform) create,
  }) {
    return create(
      transformFromTopLeftWorld(size: size, topLeftWorld: topLeftWorld),
    );
  }

  static Transform2D transformFromTopLeftWorld({
    required Size size,
    required Offset topLeftWorld,
  }) {
    return Transform2D.translation(
      topLeftWorld + Offset(size.width / 2, size.height / 2),
    );
  }

  static Offset topLeftWorld(SceneNode node) => node.boundsWorld.topLeft;

  static void setTopLeftWorld({
    required SceneNode node,
    required Offset value,
  }) {
    final delta = value - node.boundsWorld.topLeft;
    if (delta.distanceSquared < kUiEpsilonSquared) return;
    node.position = node.position + delta;
  }

  static Rect localRect(Size size) => centeredRectLocalBounds(size);
}
