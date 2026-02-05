/// Numeric tolerance helpers for robust geometry/transform math.
///
/// This module exists to avoid scattered, ad-hoc `== 0` checks on doubles.
/// It is intentionally internal (lib/src/**) and should not be exported as part
/// of the public API surface.
library;

/// Default epsilon used for "near zero" checks.
///
/// Chosen to be small enough for scene math while avoiding unstable behavior
/// around almost-degenerate transforms.
const double kEpsilon = 1e-12;

/// Epsilon squared for quantities already in squared units (e.g. length²).
const double kEpsilonSquared = 1e-24;

/// Epsilon used for UI-like positioning helpers (selection box alignment).
///
/// This is intentionally larger than [kEpsilon] to prevent micro-drift when
/// repeatedly applying nearly-identical values produced by floating-point math
/// (e.g. AABB computations under rotation).
const double kUiEpsilon = 1e-9;

/// Squared [kUiEpsilon] for comparisons in squared units (length²).
const double kUiEpsilonSquared = 1e-18;

bool nearZero(double x, [double eps = kEpsilon]) => x.abs() <= eps;

double norm1_2x2(double a, double b, double c, double d) {
  return a.abs() + b.abs() + c.abs() + d.abs();
}

/// Returns true if a 2×2 matrix is singular or numerically near-singular.
///
/// This uses a relative criterion: `|det| <= eps * (|a|+|b|+|c|+|d|)^2`.
bool isNearSingular2x2(double a, double b, double c, double d) {
  final det = a * d - b * c;
  final s = norm1_2x2(a, b, c, d);
  if (!det.isFinite || !s.isFinite || s == 0) return true;
  return det.abs() <= kEpsilon * s * s;
}
