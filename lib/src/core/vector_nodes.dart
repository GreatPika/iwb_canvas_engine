import 'dart:collection';
import 'dart:math' as math;
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

bool _isExactIdentityTransform(Transform2D t) {
  return t.a == 1 && t.b == 0 && t.c == 0 && t.d == 1 && t.tx == 0 && t.ty == 0;
}
