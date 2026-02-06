import 'dart:ui';
import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:path_drawing/path_drawing.dart';

import 'geometry.dart';
import 'numeric_clamp.dart';
import 'numeric_tolerance.dart';
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
    double opacity = 1,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
  }) : transform = transform ?? Transform2D.identity {
    this.opacity = opacity;
  }

  final NodeId id;
  final NodeType type;

  /// Additional hit-test tolerance in scene units.
  /// (Serialized as part of JSON v2.)
  ///
  /// Expected to be finite and non-negative.
  ///
  /// Runtime behavior: non-finite values are sanitized by hit-testing/bounds
  /// computations and rendering to avoid crashes; JSON serialization rejects
  /// invalid values.
  double hitPadding;

  /// Node opacity in the range `[0,1]`.
  ///
  /// Expected to be finite.
  ///
  /// Runtime behavior: values are normalized at assignment (`!finite -> 1`,
  /// clamped to `[0,1]`); JSON serialization rejects invalid values.
  double get opacity => _opacity;
  late double _opacity;
  set opacity(double value) => _opacity = clamp01Finite(value);
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
  ///
  /// This accessor is numerically robust for near-degenerate transforms and is
  /// designed to return a finite value for finite matrix components.
  double get rotationDeg {
    final t = transform;
    assert(
      t.a.isFinite && t.b.isFinite && t.c.isFinite && t.d.isFinite,
      'SceneNode.rotationDeg requires finite transform.',
    );

    final a = t.a;
    final b = t.b;
    final c = t.c;
    final d = t.d;

    final sx = math.sqrt(a * a + b * b);
    final syAbs = math.sqrt(c * c + d * d);
    if (!sx.isFinite || !syAbs.isFinite) return 0;
    if (nearZero(sx) && nearZero(syAbs)) return 0;

    final radians = (sx >= syAbs && !nearZero(sx))
        ? math.atan2(b, a)
        : math.atan2(-c, d);
    final degrees = radians * 180.0 / math.pi;
    return degrees.isFinite ? degrees : 0;
  }

  set rotationDeg(double value) {
    _requireTrsTransformForConvenienceSetter(transform, 'rotationDeg');
    transform = Transform2D.trs(
      translation: position,
      rotationDeg: value,
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }

  /// Derived X scale magnitude (convenience accessor).
  ///
  /// This value is always non-negative and represents the length of the first
  /// basis column of the 2×2 linear part. For flipped transforms (`det < 0`),
  /// the reflection sign is represented via [scaleY] (canonical TRS(+flip)
  /// decomposition).
  double get scaleX {
    final t = transform;
    assert(
      t.a.isFinite && t.b.isFinite && t.c.isFinite && t.d.isFinite,
      'SceneNode.scaleX requires finite transform.',
    );

    final a = t.a;
    final b = t.b;
    final sx = math.sqrt(a * a + b * b);
    if (!sx.isFinite) return 0;
    if (nearZero(sx)) return 0;
    return sx;
  }

  set scaleX(double value) {
    _requireTrsTransformForConvenienceSetter(transform, 'scaleX');
    transform = Transform2D.trs(
      translation: position,
      rotationDeg: rotationDeg,
      scaleX: value,
      scaleY: scaleY,
    );
  }

  /// Derived Y scale (convenience accessor).
  ///
  /// This derives the sign from the matrix determinant and the local axis
  /// direction. For general affine transforms (shear), this is a convenience
  /// accessor and may not match a unique decomposition.
  ///
  /// For flips (`det < 0`), this accessor encodes the reflection sign while
  /// [scaleX] remains a non-negative magnitude (canonical TRS(+flip)
  /// decomposition together with [rotationDeg]).
  double get scaleY {
    final t = transform;
    assert(
      t.a.isFinite && t.b.isFinite && t.c.isFinite && t.d.isFinite,
      'SceneNode.scaleY requires finite transform.',
    );

    final c = t.c;
    final d = t.d;
    final syAbs = math.sqrt(c * c + d * d);
    if (!syAbs.isFinite) return 0;
    if (nearZero(syAbs)) return 0;

    final a = t.a;
    final b = t.b;
    final det = a * d - b * c;
    if (isNearSingular2x2(a, b, c, d) || !det.isFinite) return syAbs;

    final sign = det < 0 ? -1.0 : 1.0;
    final out = sign * syAbs;
    return out.isFinite ? out : 0;
  }

  set scaleY(double value) {
    _requireTrsTransformForConvenienceSetter(transform, 'scaleY');
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
  Rect get boundsWorld {
    final local = localBounds;
    if (!_isFiniteRect(local)) return Rect.zero;
    final t = transform;
    if (!_isFiniteTransform2D(t)) return Rect.zero;
    final out = t.applyToRect(local);
    if (!_isFiniteRect(out)) return Rect.zero;
    return out;
  }
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
    if (delta.distanceSquared < kUiEpsilonSquared) return;
    position = position + delta;
  }

  Rect get _localRect => Rect.fromCenter(
    center: Offset.zero,
    width: clampNonNegativeFinite(size.width),
    height: clampNonNegativeFinite(size.height),
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
    if (delta.distanceSquared < kUiEpsilonSquared) return;
    position = position + delta;
  }

  Rect get _localRect => Rect.fromCenter(
    center: Offset.zero,
    width: clampNonNegativeFinite(size.width),
    height: clampNonNegativeFinite(size.height),
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
    if (!_isFiniteRect(bounds)) return Rect.zero;
    final baseThickness = clampNonNegativeFinite(thickness);
    return bounds.inflate(baseThickness / 2);
  }

  /// Normalizes interactive stroke geometry into local coordinates.
  ///
  /// Preconditions (validated at runtime):
  /// - [transform] must be the identity transform.
  /// - All point coordinates must be finite.
  ///
  /// Throws [StateError] when preconditions are violated.
  ///
  /// This method is intended for interactive drawing: while the user draws,
  /// the engine may temporarily store [points] in world/scene coordinates with
  /// `transform == identity`. Call this when the gesture finishes to convert
  /// geometry to local space and store the world center in [transform].
  void normalizeToLocalCenter() {
    final t = transform;
    if (!_isExactIdentityTransform(t)) {
      throw StateError(
        'StrokeNode.normalizeToLocalCenter requires transform == identity. '
        'Use StrokeNode.fromWorldPoints for non-interactive creation.',
      );
    }
    for (final p in points) {
      if (!p.dx.isFinite || !p.dy.isFinite) {
        throw StateError(
          'StrokeNode.normalizeToLocalCenter requires finite point coordinates.',
        );
      }
    }
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
  Rect get localBounds {
    if (!start.dx.isFinite ||
        !start.dy.isFinite ||
        !end.dx.isFinite ||
        !end.dy.isFinite) {
      return Rect.zero;
    }
    final baseThickness = clampNonNegativeFinite(thickness);
    return Rect.fromPoints(start, end).inflate(baseThickness / 2);
  }

  /// Normalizes interactive line geometry into local coordinates.
  ///
  /// Preconditions (validated at runtime):
  /// - [transform] must be the identity transform.
  /// - [start] and [end] must have finite coordinates.
  ///
  /// Throws [StateError] when preconditions are violated.
  ///
  /// This method is intended for interactive drawing: while the user draws,
  /// the engine may temporarily store [start]/[end] in world/scene coordinates
  /// with `transform == identity`. Call this when the gesture finishes to
  /// convert geometry to local space and store the world center in [transform].
  void normalizeToLocalCenter() {
    final t = transform;
    if (!_isExactIdentityTransform(t)) {
      throw StateError(
        'LineNode.normalizeToLocalCenter requires transform == identity. '
        'Use LineNode.fromWorldSegment for non-interactive creation.',
      );
    }
    if (!start.dx.isFinite ||
        !start.dy.isFinite ||
        !end.dx.isFinite ||
        !end.dy.isFinite) {
      throw StateError(
        'LineNode.normalizeToLocalCenter requires finite start/end coordinates.',
      );
    }
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
    if (delta.distanceSquared < kUiEpsilonSquared) return;
    position = position + delta;
  }

  Rect get _localRect => Rect.fromCenter(
    center: Offset.zero,
    width: clampNonNegativeFinite(size.width),
    height: clampNonNegativeFinite(size.height),
  );

  @override
  Rect get localBounds {
    var rect = _localRect;
    final baseStrokeWidth = clampNonNegativeFinite(strokeWidth);
    if (strokeColor != null && baseStrokeWidth > 0) {
      rect = rect.inflate(baseStrokeWidth / 2);
    }
    return rect;
  }
}

/// SVG-path based vector node.
class PathNode extends SceneNode {
  /// When enabled, `buildLocalPath()` records failure reasons and emits
  /// diagnostics logs even in release builds.
  ///
  /// By default, failures are silent in release builds and are only recorded
  /// when assertions are enabled (debug/profile).
  static bool enableBuildLocalPathDiagnostics = false;

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
  Rect? _cachedLocalPathBounds;
  String? _cachedSvgPathData;
  PathFillRule? _cachedFillRule;
  bool _cacheResolved = false;

  String? _debugLastBuildLocalPathFailureReason;
  Object? _debugLastBuildLocalPathException;
  StackTrace? _debugLastBuildLocalPathStackTrace;

  /// Debug-only failure reason for the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  String? get debugLastBuildLocalPathFailureReason =>
      _debugLastBuildLocalPathFailureReason;

  /// Debug-only exception captured from the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  Object? get debugLastBuildLocalPathException =>
      _debugLastBuildLocalPathException;

  /// Debug-only stack trace captured from the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  StackTrace? get debugLastBuildLocalPathStackTrace =>
      _debugLastBuildLocalPathStackTrace;

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
  ///
  /// By default, this method returns a defensive copy of the cached geometry so
  /// external callers cannot accidentally mutate internal cache state.
  ///
  /// For performance-sensitive internal call sites, pass `copy: false` and
  /// treat the returned path as immutable (read-only).
  Path? buildLocalPath({bool copy = true}) {
    if (_cacheResolved &&
        _cachedSvgPathData == _svgPathData &&
        _cachedFillRule == _fillRule) {
      final cached = _cachedLocalPath;
      if (cached == null) return null;
      return copy ? _copyPath(cached) : cached;
    }
    if (_svgPathData.trim().isEmpty) {
      _cacheResolved = true;
      _cachedSvgPathData = _svgPathData;
      _cachedFillRule = _fillRule;
      _cachedLocalPath = null;
      _cachedLocalPathBounds = null;
      _recordBuildLocalPathFailure(reason: 'empty-svg-path-data');
      return null;
    }
    try {
      final path = parseSvgPathData(_svgPathData);
      final metrics = path.computeMetrics();
      var hasNonZeroLength = false;
      for (final metric in metrics) {
        if (metric.length > 0) {
          hasNonZeroLength = true;
          break;
        }
      }
      if (!hasNonZeroLength) {
        _cacheResolved = true;
        _cachedSvgPathData = _svgPathData;
        _cachedFillRule = _fillRule;
        _cachedLocalPath = null;
        _cachedLocalPathBounds = null;
        _recordBuildLocalPathFailure(reason: 'svg-path-has-no-nonzero-length');
        return null;
      }
      final bounds = path.getBounds();
      final centered = path.shift(-bounds.center);
      centered.fillType = _fillRule == PathFillRule.evenOdd
          ? PathFillType.evenOdd
          : PathFillType.nonZero;
      final centeredBounds = centered.getBounds();
      _cacheResolved = true;
      _cachedSvgPathData = _svgPathData;
      _cachedFillRule = _fillRule;
      _cachedLocalPath = centered;
      _cachedLocalPathBounds = centeredBounds;
      _clearBuildLocalPathFailure();
      return copy ? _copyPath(centered) : centered;
    } catch (e, st) {
      _cacheResolved = true;
      _cachedSvgPathData = _svgPathData;
      _cachedFillRule = _fillRule;
      _cachedLocalPath = null;
      _cachedLocalPathBounds = null;
      _recordBuildLocalPathFailure(
        reason: 'exception-while-building-local-path',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Rect get localBounds {
    buildLocalPath(copy: false);
    final bounds = _cachedLocalPathBounds;
    if (bounds == null) return Rect.zero;
    if (!_isFiniteRect(bounds)) return Rect.zero;
    var rect = bounds;
    final baseStrokeWidth = clampNonNegativeFinite(strokeWidth);
    if (strokeColor != null && baseStrokeWidth > 0) {
      rect = rect.inflate(baseStrokeWidth / 2);
    }
    return rect;
  }

  void _invalidatePathCache() {
    _cacheResolved = false;
    _cachedLocalPath = null;
    _cachedLocalPathBounds = null;
    _cachedSvgPathData = null;
    _cachedFillRule = null;
  }

  static final bool _assertionsEnabled = (() {
    var enabled = false;
    assert(() {
      enabled = true;
      return true;
    }());
    return enabled;
  })();

  void _recordBuildLocalPathFailure({
    required String reason,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (enableBuildLocalPathDiagnostics) {
      _debugLastBuildLocalPathFailureReason = reason;
      _debugLastBuildLocalPathException = exception;
      _debugLastBuildLocalPathStackTrace = stackTrace;
      developer.log(
        reason,
        name: 'iwb_canvas_engine.PathNode.buildLocalPath',
        error: exception,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!_assertionsEnabled) return;
    _debugLastBuildLocalPathFailureReason = reason;
    _debugLastBuildLocalPathException = exception;
    _debugLastBuildLocalPathStackTrace = stackTrace;
  }

  void _clearBuildLocalPathFailure() {
    if (enableBuildLocalPathDiagnostics) {
      _debugLastBuildLocalPathFailureReason = null;
      _debugLastBuildLocalPathException = null;
      _debugLastBuildLocalPathStackTrace = null;
      return;
    }
    if (!_assertionsEnabled) return;
    _debugLastBuildLocalPathFailureReason = null;
    _debugLastBuildLocalPathException = null;
    _debugLastBuildLocalPathStackTrace = null;
  }

  Path _copyPath(Path source) {
    return Path.from(source);
  }
}

void _requireTrsTransformForConvenienceSetter(
  Transform2D transform,
  String setterName,
) {
  final a = transform.a;
  final b = transform.b;
  final c = transform.c;
  final d = transform.d;
  if (!a.isFinite || !b.isFinite || !c.isFinite || !d.isFinite) {
    throw StateError(
      'SceneNode.$setterName setter requires a finite transform. '
      'Set SceneNode.transform directly for general affine transforms.',
    );
  }

  // Convenience setters are TRS-only: reject sheared transforms.
  //
  // We detect shear by checking orthogonality of the basis columns:
  // first column = (a,b), second column = (c,d).
  //
  // For TRS (including flips), columns are orthogonal up to numeric tolerance.
  final dot = a * c + b * d;
  final s = norm1_2x2(a, b, c, d);
  final isOrtho = dot.abs() <= kEpsilon * s * s;
  if (!isOrtho) {
    throw StateError(
      'SceneNode.$setterName setter requires a TRS transform (no shear). '
      'Set SceneNode.transform directly for general affine transforms.',
    );
  }
}

bool _isExactIdentityTransform(Transform2D t) {
  return t.a == 1 && t.b == 0 && t.c == 0 && t.d == 1 && t.tx == 0 && t.ty == 0;
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool _isFiniteTransform2D(Transform2D transform) {
  return transform.isFinite;
}
