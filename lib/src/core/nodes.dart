import 'dart:ui';
import 'dart:math' as math;
import 'dart:developer' as developer;
import 'dart:collection';

export '../contract/ids.dart' show NodeId;
import '../contract/ids.dart';
import '../contract/path_fill_rule.dart';
import '../contract/transform_tolerance.dart'
    show isNearSingular2x2, kEpsilon, norm1_2x2;
import '../contract/transform2d.dart';
import 'geometry.dart';
import 'local_bounds_policy.dart';
import 'numeric_clamp.dart';
import 'numeric_tolerance.dart' show kUiEpsilonSquared, nearZero;

/// Supported node variants in a [Scene].
enum NodeType { image, text, stroke, line, rect, path }

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
    this.instanceRevision = 1,
    this.hitPadding = 0,
    Transform2D? transform,
    double opacity = 1,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
  }) : transform = transform ?? Transform2D.identity {
    if (instanceRevision < 1) {
      throw ArgumentError.value(
        instanceRevision,
        'instanceRevision',
        'must be >= 1',
      );
    }
    this.opacity = opacity;
  }

  final NodeId id;
  final NodeType type;
  final int instanceRevision;

  /// Additional hit-test tolerance in scene units.
  /// (Serialized as part of JSON schema.)
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
  double get rotationDeg =>
      _SceneNodeTransformConvenience.rotationDeg(transform);

  set rotationDeg(double value) {
    transform = _SceneNodeTransformConvenience.withRotationDeg(
      transform: transform,
      rotationDeg: value,
    );
  }

  /// Derived X scale magnitude (convenience accessor).
  ///
  /// This value is always non-negative and represents the length of the first
  /// basis column of the 2×2 linear part. For flipped transforms (`det < 0`),
  /// the reflection sign is represented via [scaleY] (canonical TRS(+flip)
  /// decomposition).
  double get scaleX => _SceneNodeTransformConvenience.scaleX(transform);

  set scaleX(double value) {
    transform = _SceneNodeTransformConvenience.withScaleX(
      transform: transform,
      scaleX: value,
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
  double get scaleY => _SceneNodeTransformConvenience.scaleY(transform);

  set scaleY(double value) {
    transform = _SceneNodeTransformConvenience.withScaleY(
      transform: transform,
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

/// Freehand polyline stroke node.
class StrokeNode extends SceneNode {
  StrokeNode({
    required super.id,
    required List<Offset> points,
    int pointsRevision = 0,
    required this.thickness,
    required this.color,
    super.instanceRevision,
    super.hitPadding,
    super.transform,
    super.opacity,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : super(type: NodeType.stroke) {
    _mutableGeometry = _StrokeMutableGeometryOwner(
      points,
      initialRevision: pointsRevision,
    );
  }

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
    return _VectorNodeGeometryOwner.createStrokeFromWorldPoints(
      points: points,
      create: (normalized) => StrokeNode(
        id: id,
        points: normalized.localPoints,
        thickness: thickness,
        color: color,
        hitPadding: hitPadding,
        transform: Transform2D.translation(normalized.centerWorld),
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      ),
    );
  }

  /// Stroke polyline points in local coordinates.
  ///
  /// During interactive drawing, the controller may temporarily keep points in
  /// world coordinates with `transform == identity`. The stroke is normalized
  /// when the gesture finishes.
  late final _StrokeMutableGeometryOwner _mutableGeometry;
  List<Offset> get points => _mutableGeometry.points;

  /// Monotonic geometry revision incremented on any [points] mutation.
  ///
  /// This is used by renderer caches to validate path freshness in O(1).
  int get pointsRevision => _mutableGeometry.pointsRevision;
  double thickness;
  Color color;

  @override
  Rect get localBounds {
    return strokeLocalBounds(points: points, thickness: thickness);
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
    final centerWorld = _VectorNodeGeometryOwner.normalizeStrokeToLocalCenter(
      transform: transform,
      points: points,
    );
    if (centerWorld == null) return;
    transform = Transform2D.trs(translation: centerWorld);
  }
}

final class _StrokeMutableGeometryOwner {
  _StrokeMutableGeometryOwner(
    Iterable<Offset> source, {
    int initialRevision = 0,
  }) : _storage = List<Offset>.from(source),
       _revision = initialRevision {
    if (initialRevision < 0) {
      throw ArgumentError.value(
        initialRevision,
        'initialRevision',
        'must be >= 0',
      );
    }
  }

  final List<Offset> _storage;
  int _revision;
  late final List<Offset> _pointsView = _RevisionedOffsetListView(
    _storage,
    onMutated: _markMutated,
  );

  List<Offset> get points => _pointsView;
  int get pointsRevision => _revision;

  void _markMutated() => _revision += 1;
}

final class _RevisionedOffsetListView extends ListBase<Offset>
    with
        _RevisionedOffsetListStructuralMutations,
        _RevisionedOffsetListRangeMutations,
        _RevisionedOffsetListCollectionMutations {
  _RevisionedOffsetListView(this._storage, {required void Function() onMutated})
    : _onMutated = onMutated;

  final List<Offset> _storage;
  final void Function() _onMutated;

  @override
  List<Offset> get revisionedOffsetsBase => _storage;

  @override
  void markRevisionedOffsetsMutated() => _onMutated();

  @override
  int get length => _storage.length;

  @override
  Offset operator [](int index) => _storage[index];
}

abstract interface class _RevisionedOffsetListMutationHost {
  List<Offset> get revisionedOffsetsBase;
  void markRevisionedOffsetsMutated();
}

mixin _RevisionedOffsetListStructuralMutations on ListBase<Offset>
    implements _RevisionedOffsetListMutationHost {
  @override
  set length(int value) {
    if (value == revisionedOffsetsBase.length) return;
    revisionedOffsetsBase.length = value;
    markRevisionedOffsetsMutated();
  }

  @override
  void operator []=(int index, Offset value) {
    if (revisionedOffsetsBase[index] == value) return;
    revisionedOffsetsBase[index] = value;
    markRevisionedOffsetsMutated();
  }

  @override
  void add(Offset value) {
    revisionedOffsetsBase.add(value);
    markRevisionedOffsetsMutated();
  }

  @override
  void addAll(Iterable<Offset> iterable) {
    if (iterable.isEmpty) return;
    revisionedOffsetsBase.addAll(iterable);
    markRevisionedOffsetsMutated();
  }

  @override
  void clear() {
    if (revisionedOffsetsBase.isEmpty) return;
    revisionedOffsetsBase.clear();
    markRevisionedOffsetsMutated();
  }

  @override
  void insert(int index, Offset element) {
    revisionedOffsetsBase.insert(index, element);
    markRevisionedOffsetsMutated();
  }

  @override
  void insertAll(int index, Iterable<Offset> iterable) {
    if (iterable.isEmpty) return;
    revisionedOffsetsBase.insertAll(index, iterable);
    markRevisionedOffsetsMutated();
  }

  @override
  bool remove(Object? value) {
    final removed = revisionedOffsetsBase.remove(value);
    if (removed) markRevisionedOffsetsMutated();
    return removed;
  }

  @override
  Offset removeAt(int index) {
    final removed = revisionedOffsetsBase.removeAt(index);
    markRevisionedOffsetsMutated();
    return removed;
  }

  @override
  Offset removeLast() {
    final removed = revisionedOffsetsBase.removeLast();
    markRevisionedOffsetsMutated();
    return removed;
  }

  @override
  void removeRange(int start, int end) {
    if (start == end) return;
    revisionedOffsetsBase.removeRange(start, end);
    markRevisionedOffsetsMutated();
  }
}

mixin _RevisionedOffsetListRangeMutations on ListBase<Offset>
    implements _RevisionedOffsetListMutationHost {
  @override
  void replaceRange(int start, int end, Iterable<Offset> replacements) {
    revisionedOffsetsBase.replaceRange(start, end, replacements);
    markRevisionedOffsetsMutated();
  }

  @override
  void setAll(int index, Iterable<Offset> iterable) {
    if (iterable.isEmpty) return;
    revisionedOffsetsBase.setAll(index, iterable);
    markRevisionedOffsetsMutated();
  }

  @override
  void setRange(
    int start,
    int end,
    Iterable<Offset> iterable, [
    int skipCount = 0,
  ]) {
    if (start == end) return;
    revisionedOffsetsBase.setRange(start, end, iterable, skipCount);
    markRevisionedOffsetsMutated();
  }

  @override
  void fillRange(int start, int end, [Offset? fillValue]) {
    if (start == end) return;
    revisionedOffsetsBase.fillRange(start, end, fillValue);
    markRevisionedOffsetsMutated();
  }
}

mixin _RevisionedOffsetListCollectionMutations on ListBase<Offset>
    implements _RevisionedOffsetListMutationHost {
  @override
  void removeWhere(bool Function(Offset element) test) {
    final before = revisionedOffsetsBase.length;
    revisionedOffsetsBase.removeWhere(test);
    if (revisionedOffsetsBase.length != before) {
      markRevisionedOffsetsMutated();
    }
  }

  @override
  void retainWhere(bool Function(Offset element) test) {
    final before = revisionedOffsetsBase.length;
    revisionedOffsetsBase.retainWhere(test);
    if (revisionedOffsetsBase.length != before) {
      markRevisionedOffsetsMutated();
    }
  }

  @override
  void sort([int Function(Offset a, Offset b)? compare]) {
    if (revisionedOffsetsBase.length < 2) return;
    revisionedOffsetsBase.sort(compare);
    markRevisionedOffsetsMutated();
  }

  @override
  void shuffle([math.Random? random]) {
    if (revisionedOffsetsBase.length < 2) return;
    revisionedOffsetsBase.shuffle(random);
    markRevisionedOffsetsMutated();
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
    super.instanceRevision,
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
    return _VectorNodeGeometryOwner.createLineFromWorldSegment(
      start: start,
      end: end,
      create: (normalized) => LineNode(
        id: id,
        start: normalized.localStart,
        end: normalized.localEnd,
        thickness: thickness,
        color: color,
        hitPadding: hitPadding,
        transform: Transform2D.translation(normalized.centerWorld),
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      ),
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
    return lineLocalBounds(start: start, end: end, thickness: thickness);
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
    final normalized = _VectorNodeGeometryOwner.normalizeLineToLocalCenter(
      transform: transform,
      start: start,
      end: end,
    );
    start = normalized.localStart;
    end = normalized.localEnd;
    transform = Transform2D.trs(translation: normalized.centerWorld);
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

abstract final class _SceneNodeTransformConvenience {
  static double rotationDeg(Transform2D transform) {
    _assertFiniteLinearPart(transform, 'rotationDeg');
    final sx = _scaleMagnitude(transform.a, transform.b);
    final syAbs = _scaleMagnitude(transform.c, transform.d);
    if (!sx.isFinite || !syAbs.isFinite) return 0;
    if (nearZero(sx) && nearZero(syAbs)) return 0;

    final radians = (sx >= syAbs && !nearZero(sx))
        ? math.atan2(transform.b, transform.a)
        : math.atan2(-transform.c, transform.d);
    final degrees = radians * 180.0 / math.pi;
    return degrees.isFinite ? degrees : 0;
  }

  static double scaleX(Transform2D transform) {
    _assertFiniteLinearPart(transform, 'scaleX');
    final sx = _scaleMagnitude(transform.a, transform.b);
    if (!sx.isFinite || nearZero(sx)) return 0;
    return sx;
  }

  static double scaleY(Transform2D transform) {
    _assertFiniteLinearPart(transform, 'scaleY');
    final syAbs = _scaleMagnitude(transform.c, transform.d);
    if (!syAbs.isFinite || nearZero(syAbs)) return 0;

    final det = transform.a * transform.d - transform.b * transform.c;
    if (isNearSingular2x2(transform.a, transform.b, transform.c, transform.d) ||
        !det.isFinite) {
      return syAbs;
    }

    final out = (det < 0 ? -1.0 : 1.0) * syAbs;
    return out.isFinite ? out : 0;
  }

  static Transform2D withRotationDeg({
    required Transform2D transform,
    required double rotationDeg,
  }) {
    _requireTrsTransformForConvenienceSetter(transform, 'rotationDeg');
    return Transform2D.trs(
      translation: transform.translation,
      rotationDeg: rotationDeg,
      scaleX: scaleX(transform),
      scaleY: scaleY(transform),
    );
  }

  static Transform2D withScaleX({
    required Transform2D transform,
    required double scaleX,
  }) {
    _requireTrsTransformForConvenienceSetter(transform, 'scaleX');
    return Transform2D.trs(
      translation: transform.translation,
      rotationDeg: rotationDeg(transform),
      scaleX: scaleX,
      scaleY: scaleY(transform),
    );
  }

  static Transform2D withScaleY({
    required Transform2D transform,
    required double scaleY,
  }) {
    _requireTrsTransformForConvenienceSetter(transform, 'scaleY');
    return Transform2D.trs(
      translation: transform.translation,
      rotationDeg: rotationDeg(transform),
      scaleX: scaleX(transform),
      scaleY: scaleY,
    );
  }

  static void _assertFiniteLinearPart(
    Transform2D transform,
    String memberName,
  ) {
    assert(
      transform.a.isFinite &&
          transform.b.isFinite &&
          transform.c.isFinite &&
          transform.d.isFinite,
      'SceneNode.$memberName requires finite transform.',
    );
  }

  static double _scaleMagnitude(double x, double y) {
    return math.sqrt(x * x + y * y);
  }
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

abstract final class _VectorNodeGeometryOwner {
  static StrokeNode createStrokeFromWorldPoints({
    required List<Offset> points,
    required StrokeNode Function(_CenteredWorldPoints normalized) create,
  }) {
    return create(normalizeWorldPoints(points));
  }

  static LineNode createLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required LineNode Function(_CenteredWorldSegment normalized) create,
  }) {
    return create(normalizeWorldSegment(start: start, end: end));
  }

  static _CenteredWorldPoints normalizeWorldPoints(List<Offset> points) {
    final centerWorld = points.isEmpty
        ? Offset.zero
        : aabbFromPoints(points).center;
    return _CenteredWorldPoints(
      centerWorld: centerWorld,
      localPoints: points
          .map((point) => point - centerWorld)
          .toList(growable: false),
    );
  }

  static Offset? normalizeStrokeToLocalCenter({
    required Transform2D transform,
    required List<Offset> points,
  }) {
    _requireExactIdentityTransform(
      transform,
      'StrokeNode.normalizeToLocalCenter',
      'Use StrokeNode.fromWorldPoints for non-interactive creation.',
    );
    _requireFinitePoints(
      points,
      'StrokeNode.normalizeToLocalCenter requires finite point coordinates.',
    );
    if (points.isEmpty) return null;
    final centerWorld = aabbFromPoints(points).center;
    for (var i = 0; i < points.length; i++) {
      points[i] = points[i] - centerWorld;
    }
    return centerWorld;
  }

  static _CenteredWorldSegment normalizeWorldSegment({
    required Offset start,
    required Offset end,
  }) {
    final centerWorld = Rect.fromPoints(start, end).center;
    return _CenteredWorldSegment(
      centerWorld: centerWorld,
      localStart: start - centerWorld,
      localEnd: end - centerWorld,
    );
  }

  static _CenteredWorldSegment normalizeLineToLocalCenter({
    required Transform2D transform,
    required Offset start,
    required Offset end,
  }) {
    _requireExactIdentityTransform(
      transform,
      'LineNode.normalizeToLocalCenter',
      'Use LineNode.fromWorldSegment for non-interactive creation.',
    );
    if (!start.dx.isFinite ||
        !start.dy.isFinite ||
        !end.dx.isFinite ||
        !end.dy.isFinite) {
      throw StateError(
        'LineNode.normalizeToLocalCenter requires finite start/end coordinates.',
      );
    }
    return normalizeWorldSegment(start: start, end: end);
  }

  static void _requireExactIdentityTransform(
    Transform2D transform,
    String methodName,
    String hint,
  ) {
    if (_isExactIdentityTransform(transform)) return;
    throw StateError('$methodName requires transform == identity. $hint');
  }

  static void _requireFinitePoints(List<Offset> points, String message) {
    for (final point in points) {
      if (point.dx.isFinite && point.dy.isFinite) continue;
      throw StateError(message);
    }
  }
}

final class _CenteredWorldPoints {
  const _CenteredWorldPoints({
    required this.centerWorld,
    required this.localPoints,
  });

  final Offset centerWorld;
  final List<Offset> localPoints;
}

final class _CenteredWorldSegment {
  const _CenteredWorldSegment({
    required this.centerWorld,
    required this.localStart,
    required this.localEnd,
  });

  final Offset centerWorld;
  final Offset localStart;
  final Offset localEnd;
}

/// SVG-path based vector node.
class PathNode extends SceneNode {
  /// When enabled, `buildLocalPath()` records failure reasons and emits
  /// diagnostics logs even in release builds.
  ///
  /// By default, failures are silent in release builds and are only recorded
  /// when assertions are enabled (debug/profile).
  // ignore: avoid-global-state, intentional process-wide diagnostics toggle
  static bool enableBuildLocalPathDiagnostics = false;

  PathNode({
    required super.id,
    required String svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    PathFillRule fillRule = PathFillRule.nonZero,
    super.instanceRevision,
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

  late final _PathNodeLocalPathCacheOwner _localPathCache =
      _PathNodeLocalPathCacheOwner();

  /// Debug-only failure reason for the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  String? get debugLastBuildLocalPathFailureReason =>
      _localPathCache.debugLastBuildLocalPathFailureReason;

  /// Debug-only exception captured from the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  Object? get debugLastBuildLocalPathException =>
      _localPathCache.debugLastBuildLocalPathException;

  /// Debug-only stack trace captured from the last `buildLocalPath()` attempt.
  ///
  /// This value is populated when assertions are enabled, or when
  /// [enableBuildLocalPathDiagnostics] is true.
  StackTrace? get debugLastBuildLocalPathStackTrace =>
      _localPathCache.debugLastBuildLocalPathStackTrace;

  String get svgPathData => _svgPathData;
  set svgPathData(String value) {
    if (_svgPathData == value) return;
    _svgPathData = value;
    _localPathCache.invalidate();
  }

  PathFillRule get fillRule => _fillRule;
  set fillRule(PathFillRule value) {
    if (_fillRule == value) return;
    _fillRule = value;
    _localPathCache.invalidate();
  }

  /// Builds a local path centered around (0,0), or returns null if invalid.
  ///
  /// The returned path is in the node's local coordinate space. The caller is
  /// responsible for applying [transform].
  ///
  /// This method returns a defensive copy of the cached geometry so external
  /// callers cannot accidentally mutate internal cache state.
  Path? buildLocalPath() => _localPathCache.buildLocalPath(
    _PathNodeCacheRequest(
      svgPathData: _svgPathData,
      fillRule: _fillRule,
      diagnosticsEnabled: enableBuildLocalPathDiagnostics,
      assertionsEnabled: _assertionsEnabled,
    ),
  );

  @override
  Rect get localBounds => _localPathCache.resolveLocalBounds(
    request: _PathNodeCacheRequest(
      svgPathData: _svgPathData,
      fillRule: _fillRule,
      diagnosticsEnabled: enableBuildLocalPathDiagnostics,
      assertionsEnabled: _assertionsEnabled,
    ),
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  );

  static final bool _assertionsEnabled = (() {
    var enabled = false;
    assert(() {
      enabled = true;
      return true;
    }());
    return enabled;
  })();
}

final class _PathNodeLocalPathCacheOwner {
  Path? _cachedLocalPath;
  Rect? _cachedLocalPathBounds;
  String? _cachedSvgPathData;
  PathFillRule? _cachedFillRule;
  bool _cacheResolved = false;

  String? _debugLastBuildLocalPathFailureReason;
  Object? _debugLastBuildLocalPathException;
  StackTrace? _debugLastBuildLocalPathStackTrace;

  String? get debugLastBuildLocalPathFailureReason =>
      _debugLastBuildLocalPathFailureReason;
  Object? get debugLastBuildLocalPathException =>
      _debugLastBuildLocalPathException;
  StackTrace? get debugLastBuildLocalPathStackTrace =>
      _debugLastBuildLocalPathStackTrace;

  Path? buildLocalPath(_PathNodeCacheRequest request) {
    final cached = _resolve(request);
    if (cached == null) return null;
    return Path.from(cached);
  }

  Rect resolveLocalBounds({
    required _PathNodeCacheRequest request,
    required Color? strokeColor,
    required double strokeWidth,
  }) {
    _resolve(request);
    final bounds = _cachedLocalPathBounds;
    if (bounds == null) return Rect.zero;
    return strokeAwareLocalBounds(
      baseBounds: bounds,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
    );
  }

  void invalidate() {
    _cacheResolved = false;
    _cachedLocalPath = null;
    _cachedLocalPathBounds = null;
    _cachedSvgPathData = null;
    _cachedFillRule = null;
  }

  Path? _resolve(_PathNodeCacheRequest request) {
    if (_hasMatchingResolvedCache(request)) return _cachedLocalPath;
    if (request.hasEmptySvgPathData) {
      _rememberFailure(request, reason: 'empty-svg-path-data');
      return null;
    }
    return _resolveParsedPath(request);
  }

  Path? _resolveParsedPath(_PathNodeCacheRequest request) {
    try {
      final path = parseSvgPathDataOrThrow(request.svgPathData);
      if (!hasDrawablePathMetric(path)) {
        _rememberFailure(request, reason: 'svg-path-has-no-nonzero-length');
        return null;
      }
      return _rememberSuccess(request, path);
    } catch (e, st) {
      _rememberFailure(
        request,
        reason: 'exception-while-building-local-path',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  bool _hasMatchingResolvedCache(_PathNodeCacheRequest request) {
    return _cacheResolved &&
        _cachedSvgPathData == request.svgPathData &&
        _cachedFillRule == request.fillRule;
  }

  Path _rememberSuccess(_PathNodeCacheRequest request, Path path) {
    final geometry = centerPathGeometry(path, fillType: request.fillType);
    _cacheResolved = true;
    _cachedSvgPathData = request.svgPathData;
    _cachedFillRule = request.fillRule;
    _cachedLocalPath = geometry.localPath;
    _cachedLocalPathBounds = geometry.localBounds;
    _clearRecordedFailure(request);
    return geometry.localPath;
  }

  void _rememberFailure(
    _PathNodeCacheRequest request, {
    required String reason,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    _cacheResolved = true;
    _cachedSvgPathData = request.svgPathData;
    _cachedFillRule = request.fillRule;
    _cachedLocalPath = null;
    _cachedLocalPathBounds = null;
    _recordBuildLocalPathFailure(
      request,
      reason: reason,
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  void _recordBuildLocalPathFailure(
    _PathNodeCacheRequest request, {
    required String reason,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (request.diagnosticsEnabled) {
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
    if (!request.assertionsEnabled) return;
    _debugLastBuildLocalPathFailureReason = reason;
    _debugLastBuildLocalPathException = exception;
    _debugLastBuildLocalPathStackTrace = stackTrace;
  }

  void _clearRecordedFailure(_PathNodeCacheRequest request) {
    if (!request.diagnosticsEnabled && !request.assertionsEnabled) return;
    _debugLastBuildLocalPathFailureReason = null;
    _debugLastBuildLocalPathException = null;
    _debugLastBuildLocalPathStackTrace = null;
  }
}

final class _PathNodeCacheRequest {
  const _PathNodeCacheRequest({
    required this.svgPathData,
    required this.fillRule,
    required this.diagnosticsEnabled,
    required this.assertionsEnabled,
  });

  final String svgPathData;
  final PathFillRule fillRule;
  final bool diagnosticsEnabled;
  final bool assertionsEnabled;

  bool get hasEmptySvgPathData => svgPathData.trim().isEmpty;
  PathFillType get fillType => fillRule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
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
