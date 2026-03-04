/// Numeric tolerance helpers for robust geometry/transform math.
///
/// This module exists to avoid scattered, ad-hoc `== 0` checks on doubles.
/// It is intentionally internal (lib/src/**) and should not be exported as part
/// of the public API surface.
library;

import '../contract/transform_tolerance.dart' show kEpsilon;

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

/// Returns true when [x] is numerically close to zero.
bool nearZero(double x, [double eps = kEpsilon]) => x.abs() <= eps;
