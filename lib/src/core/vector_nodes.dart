import 'dart:collection';
import 'dart:ui';

import '../contract/ids.dart';
import '../contract/scene_model_invariants.dart';
import '../contract/transform2d.dart';
import 'geometry.dart';
import 'scene_node.dart';

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
    validateStrokePointCount(points.length, name: 'points', source: points);
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

  /// Replaces the full local-space stroke geometry through the canonical owner.
  ///
  /// Rejects non-finite coordinates and point lists that exceed the shared
  /// stroke point limit. Returns `true` only when the logical geometry changes.
  bool replacePoints(List<Offset> points) {
    return _mutableGeometry.replacePoints(points);
  }

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
    final normalized = _VectorNodeGeometryOwner.normalizeStrokeToLocalCenter(
      transform: transform,
      points: points,
    );
    if (normalized == null) return;
    replacePoints(normalized.localPoints);
    transform = Transform2D.trs(translation: normalized.centerWorld);
  }
}

final class _StrokeMutableGeometryOwner {
  _StrokeMutableGeometryOwner(
    Iterable<Offset> source, {
    int initialRevision = 0,
  }) : _revision = initialRevision {
    if (initialRevision < 0) {
      throw ArgumentError.value(
        initialRevision,
        'initialRevision',
        'must be >= 0',
      );
    }
    _storage = _validatedPointsCopy(source);
  }

  late final List<Offset> _storage;
  int _revision;
  late final List<Offset> _pointsView = UnmodifiableListView<Offset>(_storage);

  List<Offset> get points => _pointsView;
  int get pointsRevision => _revision;

  bool replacePoints(List<Offset> nextPoints) {
    final nextStorage = _validatedPointsCopy(nextPoints);
    if (_hasSamePoints(nextStorage)) {
      return false;
    }
    _storage
      ..clear()
      ..addAll(nextStorage);
    _revision += 1;
    return true;
  }

  bool _hasSamePoints(List<Offset> other) {
    if (_storage.length != other.length) {
      return false;
    }
    for (var index = 0; index < _storage.length; index++) {
      if (_storage[index] != other[index]) {
        return false;
      }
    }
    return true;
  }

  static List<Offset> _validatedPointsCopy(Iterable<Offset> source) {
    final copy = List<Offset>.from(source, growable: true);
    validateStrokePointCount(copy.length, name: 'points', source: source);
    for (final point in copy) {
      if (point.dx.isFinite && point.dy.isFinite) {
        continue;
      }
      throw ArgumentError.value(
        source,
        'points',
        'All points must have finite coordinates.',
      );
    }
    return copy;
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

  static _CenteredWorldPoints? normalizeStrokeToLocalCenter({
    required Transform2D transform,
    required List<Offset> points,
  }) {
    _requireExactIdentityTransform(
      transform,
      'StrokeNode.normalizeToLocalCenter',
      'Use StrokeNode.fromWorldPoints for non-interactive creation.',
    );
    if (points.isEmpty) return null;
    return normalizeWorldPoints(points);
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

bool _isExactIdentityTransform(Transform2D t) {
  return t.a == 1 && t.b == 0 && t.c == 0 && t.d == 1 && t.tx == 0 && t.ty == 0;
}
