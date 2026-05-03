import 'dart:ui';

import '../contract/ids.dart';
import '../contract/runtime_node_value_validation.dart';
import '../contract/transform2d.dart';
import 'local_bounds_policy.dart';
import 'numeric_tolerance.dart' show kUiEpsilonSquared;
import 'scene_node.dart';
import 'text_node_layout_state.dart';

/// Raster image node referenced by [imageId] and drawn at [size].
class ImageNode extends SceneNode {
  ImageNode({
    required super.id,
    required String imageId,
    required Size size,
    Size? naturalSize,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.image) {
    this.imageId = imageId;
    this.size = size;
    this.naturalSize = naturalSize;
  }

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

  String get imageId => _imageId;
  late String _imageId;
  set imageId(String value) {
    _imageId = validateImageIdValue(value, name: 'imageId');
  }

  Size get size => _size;
  late Size _size;
  set size(Size value) {
    _size = validateNonNegativeSize(value, name: 'size');
  }

  Size? get naturalSize => _naturalSize;
  Size? _naturalSize;
  set naturalSize(Size? value) {
    _naturalSize = value == null
        ? null
        : validateNonNegativeSize(value, name: 'naturalSize');
  }

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => _BoxNodePlacementOwner.topLeftWorld(this);
  set topLeftWorld(Offset value) =>
      _BoxNodePlacementOwner.setTopLeftWorld(node: this, value: value);

  @override
  Rect get localBounds => _BoxNodePlacementOwner.localRect(size);
}

/// Text node with layout-derived bounds and basic styling.
class TextNode extends SceneNode {
  TextNode({
    required super.id,
    required String text,
    double fontSize = 24,
    required this.color,
    TextAlign align = TextAlign.left,
    TextDirection textDirection = TextDirection.ltr,
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    String? fontFamily,
    double? maxWidth,
    double? lineHeight,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : _layoutState = TextNodeLayoutState(
         text: text,
         fontSize: fontSize,
         align: align,
         textDirection: textDirection,
         isBold: isBold,
         isItalic: isItalic,
         isUnderline: isUnderline,
         fontFamily: fontFamily,
         maxWidth: maxWidth,
         lineHeight: lineHeight,
       ),
       super(type: NodeType.text);

  /// Creates a text node positioned by its axis-aligned world top-left corner.
  ///
  /// This helper is AABB-based: rotation/shear affects [boundsWorld], so
  /// [topLeftWorld] is intended for UI-like positioning (selection box).
  factory TextNode.fromTopLeftWorld({
    required NodeId id,
    required String text,
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
    final node = TextNode(
      id: id,
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
      hitPadding: hitPadding,
      opacity: opacity,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
    node.transform = _BoxNodePlacementOwner.transformFromTopLeftWorld(
      size: node._layoutState.derivedSize(color: node.color),
      topLeftWorld: topLeftWorld,
    );
    return node;
  }

  final TextNodeLayoutState _layoutState;

  String get text => _layoutState.text;
  set text(String value) => _layoutState.text = value;

  double get fontSize => _layoutState.fontSize;
  set fontSize(double value) => _layoutState.fontSize = value;

  Color color;

  TextAlign get align => _layoutState.align;
  set align(TextAlign value) => _layoutState.align = value;

  TextDirection get textDirection => _layoutState.textDirection;
  set textDirection(TextDirection value) => _layoutState.textDirection = value;

  bool get isBold => _layoutState.isBold;
  set isBold(bool value) => _layoutState.isBold = value;

  bool get isItalic => _layoutState.isItalic;
  set isItalic(bool value) => _layoutState.isItalic = value;

  bool get isUnderline => _layoutState.isUnderline;
  set isUnderline(bool value) => _layoutState.isUnderline = value;

  String? get fontFamily => _layoutState.fontFamily;
  set fontFamily(String? value) => _layoutState.fontFamily = value;

  double? get maxWidth => _layoutState.maxWidth;
  set maxWidth(double? value) => _layoutState.maxWidth = value;

  double? get lineHeight => _layoutState.lineHeight;
  set lineHeight(double? value) => _layoutState.lineHeight = value;

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => _BoxNodePlacementOwner.topLeftWorld(this);
  set topLeftWorld(Offset value) =>
      _BoxNodePlacementOwner.setTopLeftWorld(node: this, value: value);

  @override
  Rect get localBounds =>
      _BoxNodePlacementOwner.localRect(_layoutState.derivedSize(color: color));
}

/// Box node with optional fill and stroke.
class RectNode extends SceneNode {
  RectNode({
    required super.id,
    required Size size,
    this.fillColor,
    this.strokeColor,
    double strokeWidth = 1,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.rect) {
    this.size = size;
    this.strokeWidth = strokeWidth;
  }

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

  Size get size => _size;
  late Size _size;
  set size(Size value) {
    _size = validateNonNegativeSize(value, name: 'size');
  }

  Color? fillColor;
  Color? strokeColor;
  double get strokeWidth => _strokeWidth;
  late double _strokeWidth;
  set strokeWidth(double value) {
    _strokeWidth = validateNonNegativeFiniteDoubleValue(
      value,
      name: 'strokeWidth',
    );
  }

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
