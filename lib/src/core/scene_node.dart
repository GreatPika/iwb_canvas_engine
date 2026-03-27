import 'dart:math' as math;
import 'dart:ui';

import '../contract/ids.dart';
import '../contract/transform_tolerance.dart'
    show isNearSingular2x2, kEpsilon, norm1_2x2;
import '../contract/transform2d.dart';
import 'numeric_clamp.dart';
import 'numeric_tolerance.dart' show nearZero;

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

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool _isFiniteTransform2D(Transform2D transform) {
  return transform.isFinite;
}
