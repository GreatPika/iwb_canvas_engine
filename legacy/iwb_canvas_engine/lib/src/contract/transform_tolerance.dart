/// Numeric tolerance helpers owned by the contract-facing transform layer.
library;

/// Default epsilon used for transform near-singular checks.
const double kEpsilon = 1e-12;

double norm1_2x2(double a, double b, double c, double d) {
  return a.abs() + b.abs() + c.abs() + d.abs();
}

/// Returns true if a 2x2 matrix is singular or numerically near-singular.
///
/// This uses a relative criterion: `|det| <= eps * (|a|+|b|+|c|+|d|)^2`.
bool isNearSingular2x2(double a, double b, double c, double d) {
  final det = a * d - b * c;
  final s = norm1_2x2(a, b, c, d);
  if (!det.isFinite || !s.isFinite || s == 0) return true;
  return det.abs() <= kEpsilon * s * s;
}
