import 'dart:ui';
import 'dart:math' as math;

import 'package:path_drawing/path_drawing.dart';

import 'geometry.dart';
import 'transform2d.dart';

/// Supported node variants in a [Scene].
enum NodeType { image, text, stroke, line, rect, path }

/// Fill rule for [PathNode] geometry.
enum PathFillRule { nonZero, evenOdd }

/// Stable node identifier used for selection and action events.
typedef NodeId = String;

/// Base class for all nodes stored in a [Scene].
///
/// The model is mutable by design.
///
/// [transform] is the single source of truth for translation/rotation/scale.
/// Geometry is stored in the node's local coordinate space around (0,0).
abstract class SceneNode {
  SceneNode({
    required this.id,
    required this.type,
    this.hitPadding = 0,
    Transform2D? transform,
    this.opacity = 1,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
  }) : transform = transform ?? Transform2D.identity;

  final NodeId id;
  final NodeType type;

  /// Additional hit-test tolerance in scene units.
  /// (Serialized as part of JSON v2.)
  double hitPadding;
  double opacity;
  bool isVisible;
  bool isSelectable;
  bool isLocked;
  bool isDeletable;
  bool isTransformable;

  /// Local-to-world node transform.
  Transform2D transform;

  /// Translation component of [transform].
  Offset get position => transform.translation;
  set position(Offset value) => transform = transform.withTranslation(value);

  /// Derived rotation in degrees.
  ///
  /// Note: for general affine transforms (shear), a unique decomposition into
  /// rotation+scale is not well-defined. This getter assumes a rotation+scale
  /// form and is intended as a convenience accessor.
  double get rotationDeg {
    final a = transform.a;
    final b = transform.b;
    if (a == 0 && b == 0) return 0;
    return math.atan2(b, a) * 180.0 / math.pi;
  }

  set rotationDeg(double value) {
    transform = Transform2D.trs(
      translation: position,
      rotationDeg: value,
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }

  /// Derived X scale (convenience accessor).
  double get scaleX {
    final a = transform.a;
    final b = transform.b;
    return math.sqrt(a * a + b * b);
  }

  set scaleX(double value) {
    transform = Transform2D.trs(
      translation: position,
      rotationDeg: rotationDeg,
      scaleX: value,
      scaleY: scaleY,
    );
  }

  /// Derived Y scale (convenience accessor).
  ///
  /// This derives the sign from the matrix determinant and [scaleX], so
  /// reflections may be represented as a 180° rotation + negative Y scale.
  double get scaleY {
    final sx = scaleX;
    if (sx == 0) return 0;
    final det = transform.a * transform.d - transform.b * transform.c;
    return det / sx;
  }

  set scaleY(double value) {
    transform = Transform2D.trs(
      translation: position,
      rotationDeg: rotationDeg,
      scaleX: scaleX,
      scaleY: value,
    );
  }

  /// Axis-aligned bounds in local coordinates.
  Rect get localBounds;

  /// Axis-aligned bounds in world coordinates.
  Rect get boundsWorld => transform.applyToRect(localBounds);
}

/// Raster image node referenced by [imageId] and drawn at [size].
class ImageNode extends SceneNode {
  ImageNode({
    required super.id,
    required this.imageId,
    required this.size,
    this.naturalSize,
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
    final centerWorld = topLeftWorld + Offset(size.width / 2, size.height / 2);
    return ImageNode(
      id: id,
      imageId: imageId,
      size: size,
      naturalSize: naturalSize,
      hitPadding: hitPadding,
      transform: Transform2D.translation(centerWorld),
      opacity: opacity,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
  }

  String imageId;
  Size size;
  Size? naturalSize;

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => boundsWorld.topLeft;
  set topLeftWorld(Offset value) {
    final delta = value - boundsWorld.topLeft;
    if (delta == Offset.zero) return;
    position = position + delta;
  }

  Rect get _localRect => Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );

  @override
  Rect get localBounds => _localRect;
}

/// Text node with a fixed layout box ([size]) and basic styling.
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
    final centerWorld = topLeftWorld + Offset(size.width / 2, size.height / 2);
    return TextNode(
      id: id,
      text: text,
      size: size,
      fontSize: fontSize,
      color: color,
      align: align,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      fontFamily: fontFamily,
      maxWidth: maxWidth,
      lineHeight: lineHeight,
      hitPadding: hitPadding,
      transform: Transform2D.translation(centerWorld),
      opacity: opacity,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
  }

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

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => boundsWorld.topLeft;
  set topLeftWorld(Offset value) {
    final delta = value - boundsWorld.topLeft;
    if (delta == Offset.zero) return;
    position = position + delta;
  }

  Rect get _localRect => Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );

  @override
  Rect get localBounds => _localRect;
}

/// Freehand polyline stroke node.
class StrokeNode extends SceneNode {
  StrokeNode({
    required super.id,
    required List<Offset> points,
    required this.thickness,
    required this.color,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : points = List<Offset>.from(points),
       super(type: NodeType.stroke);

  factory StrokeNode.fromWorldPoints({
    required NodeId id,
    required List<Offset> points,
    required double thickness,
    required Color color,
    double hitPadding = 0,
    double opacity = 1,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final bounds = points.isEmpty ? Rect.zero : aabbFromPoints(points);
    final centerWorld = bounds.center;
    final local = points.map((p) => p - centerWorld).toList(growable: false);
    return StrokeNode(
      id: id,
      points: local,
      thickness: thickness,
      color: color,
      hitPadding: hitPadding,
      transform: Transform2D.translation(centerWorld),
      opacity: opacity,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
  }

  /// Stroke polyline points in local coordinates.
  ///
  /// During interactive drawing, the controller may temporarily keep points in
  /// world coordinates with `transform == identity`. The stroke is normalized
  /// when the gesture finishes.
  final List<Offset> points;
  double thickness;
  Color color;

  @override
  Rect get localBounds {
    if (points.isEmpty) return Rect.zero;
    final bounds = aabbFromPoints(points);
    return bounds.inflate(thickness / 2);
  }

  void normalizeToLocalCenter() {
    if (points.isEmpty) return;
    final bounds = aabbFromPoints(points);
    final centerWorld = bounds.center;
    for (var i = 0; i < points.length; i++) {
      points[i] = points[i] - centerWorld;
    }
    transform = Transform2D.trs(translation: centerWorld);
  }
}

/// Straight segment node defined by [start] and [end] points.
class LineNode extends SceneNode {
  LineNode({
    required super.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.line);

  factory LineNode.fromWorldSegment({
    required NodeId id,
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    double hitPadding = 0,
    double opacity = 1,
    bool isVisible = true,
    bool isSelectable = true,
    bool isLocked = false,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    final bounds = Rect.fromPoints(start, end);
    final centerWorld = bounds.center;
    return LineNode(
      id: id,
      start: start - centerWorld,
      end: end - centerWorld,
      thickness: thickness,
      color: color,
      hitPadding: hitPadding,
      transform: Transform2D.translation(centerWorld),
      opacity: opacity,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
  }

  /// Local-space start point.
  Offset start;

  /// Local-space end point.
  Offset end;
  double thickness;
  Color color;

  @override
  Rect get localBounds => Rect.fromPoints(start, end).inflate(thickness / 2);

  void normalizeToLocalCenter() {
    final bounds = Rect.fromPoints(start, end);
    final centerWorld = bounds.center;
    start = start - centerWorld;
    end = end - centerWorld;
    transform = Transform2D.trs(translation: centerWorld);
  }
}

/// Box node with optional fill and stroke.
class RectNode extends SceneNode {
  RectNode({
    required super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
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
    final centerWorld = topLeftWorld + Offset(size.width / 2, size.height / 2);
    return RectNode(
      id: id,
      size: size,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      hitPadding: hitPadding,
      transform: Transform2D.translation(centerWorld),
      opacity: opacity,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    );
  }

  Size size;
  Color? fillColor;
  Color? strokeColor;
  double strokeWidth;

  /// Axis-aligned world top-left corner of this node's bounds.
  ///
  /// This is based on [boundsWorld] and is intended for UI-like positioning.
  Offset get topLeftWorld => boundsWorld.topLeft;
  set topLeftWorld(Offset value) {
    final delta = value - boundsWorld.topLeft;
    if (delta == Offset.zero) return;
    position = position + delta;
  }

  Rect get _localRect => Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );

  @override
  Rect get localBounds => _localRect;
}

/// SVG-path based vector node.
class PathNode extends SceneNode {
  PathNode({
    required super.id,
    required String svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    PathFillRule fillRule = PathFillRule.nonZero,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : _svgPathData = svgPathData,
       _fillRule = fillRule,
       super(type: NodeType.path);

  Color? fillColor;
  Color? strokeColor;
  double strokeWidth;
  String _svgPathData;
  PathFillRule _fillRule;

  /// Cached local path to avoid reparsing SVG data during culling and selection.
  /// Invariant: cache is valid only while svgPathData and fillRule are unchanged.
  /// Validate via core_nodes_test "PathNode invalidates cached path".
  Path? _cachedLocalPath;
  String? _cachedSvgPathData;
  PathFillRule? _cachedFillRule;
  bool _cacheResolved = false;

  String get svgPathData => _svgPathData;
  set svgPathData(String value) {
    if (_svgPathData == value) return;
    _svgPathData = value;
    _invalidatePathCache();
  }

  PathFillRule get fillRule => _fillRule;
  set fillRule(PathFillRule value) {
    if (_fillRule == value) return;
    _fillRule = value;
    _invalidatePathCache();
  }

  /// Builds a local path centered around (0,0), or returns null if invalid.
  ///
  /// The returned path is in the node's local coordinate space. The caller is
  /// responsible for applying [transform].
  Path? buildLocalPath() {
    if (_cacheResolved &&
        _cachedSvgPathData == _svgPathData &&
        _cachedFillRule == _fillRule) {
      return _cachedLocalPath;
    }
    if (_svgPathData.trim().isEmpty) {
      _cacheResolved = true;
      _cachedSvgPathData = _svgPathData;
      _cachedFillRule = _fillRule;
      _cachedLocalPath = null;
      return null;
    }
    try {
      final path = parseSvgPathData(_svgPathData);
      final bounds = path.getBounds();
      if (bounds.isEmpty) {
        _cacheResolved = true;
        _cachedSvgPathData = _svgPathData;
        _cachedFillRule = _fillRule;
        _cachedLocalPath = null;
        return null;
      }
      final centered = path.shift(-bounds.center);
      centered.fillType = _fillRule == PathFillRule.evenOdd
          ? PathFillType.evenOdd
          : PathFillType.nonZero;
      _cacheResolved = true;
      _cachedSvgPathData = _svgPathData;
      _cachedFillRule = _fillRule;
      _cachedLocalPath = centered;
      return centered;
    } catch (_) {
      _cacheResolved = true;
      _cachedSvgPathData = _svgPathData;
      _cachedFillRule = _fillRule;
      _cachedLocalPath = null;
      return null;
    }
  }

  Rect? _pathBounds() {
    final path = buildLocalPath();
    if (path == null) return null;
    final bounds = path.getBounds();
    return bounds.isEmpty ? null : bounds;
  }

  @override
  Rect get localBounds {
    final bounds = _pathBounds();
    if (bounds == null) return Rect.zero;
    var rect = bounds;
    if (strokeColor != null && strokeWidth > 0) {
      rect = rect.inflate(strokeWidth / 2);
    }
    return rect;
  }

  void _invalidatePathCache() {
    _cacheResolved = false;
    _cachedLocalPath = null;
    _cachedSvgPathData = null;
    _cachedFillRule = null;
  }
}
