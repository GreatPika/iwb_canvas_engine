import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import 'geometry.dart';

/// Supported node variants in a [Scene].
enum NodeType { image, text, stroke, line, rect, path }

/// Fill rule for [PathNode] geometry.
enum PathFillRule { nonZero, evenOdd }

/// Stable node identifier used for selection and action events.
typedef NodeId = String;

/// Base class for all nodes stored in a [Scene].
///
/// The model is mutable by design. Box-based nodes use [position] as the center.
/// Line and stroke nodes store their geometry in scene coordinates, and expose
/// [position] as a derived bounding-box center.
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

  /// Axis-aligned bounding box in scene coordinates.
  Rect get aabb;
}

/// Raster image node referenced by [imageId] and drawn at [size].
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

/// Freehand polyline stroke node.
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
  }) : points = List<Offset>.from(points),
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

/// Straight segment node defined by [start] and [end] points.
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

/// Box node with optional fill and stroke.
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

/// SVG-path based vector node.
class PathNode extends SceneNode {
  PathNode({
    required super.id,
    required String svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    PathFillRule fillRule = PathFillRule.nonZero,
    super.rotationDeg,
    super.scaleX,
    super.scaleY,
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
  Offset _position = Offset.zero;

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

  @override
  Offset get position => _position;

  @override
  set position(Offset value) => _position = value;

  /// Builds a local path centered around (0,0), or returns null if invalid.
  ///
  /// The returned path is in the node's local coordinate space. The caller is
  /// responsible for applying [position], [rotationDeg], and scaling.
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
  Rect get aabb {
    final bounds = _pathBounds();
    if (bounds == null) return Rect.zero;
    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: bounds.width,
      height: bounds.height,
    );
    return aabbForTransformedRect(
      localRect: localRect,
      position: position,
      rotationDeg: rotationDeg,
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }

  void _invalidatePathCache() {
    _cacheResolved = false;
    _cachedLocalPath = null;
    _cachedSvgPathData = null;
    _cachedFillRule = null;
  }
}
