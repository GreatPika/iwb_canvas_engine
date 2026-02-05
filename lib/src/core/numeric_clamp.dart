/// Numeric clamping helpers for runtime safety.
///
/// Note: JSON import/export applies stricter validation and throws on invalid
/// values. These helpers exist to make rendering, bounds, and hit-testing
/// robust against invalid runtime values (e.g. NaN/Infinity, negative
/// thickness) without throwing.
library;

import 'dart:ui';

double sanitizeFinite(double value, {required double fallback}) {
  if (!value.isFinite) return fallback;
  return value;
}

double clampNonNegativeFinite(double value, {double fallback = 0.0}) {
  if (!value.isFinite) return fallback;
  if (value < 0) return 0.0;
  return value;
}

double clampPositiveFinite(double value, {required double fallback}) {
  if (!value.isFinite) return fallback;
  if (value <= 0) return fallback;
  return value;
}

double clamp01Finite(double value, {double fallback = 1.0}) {
  if (!value.isFinite) return fallback;
  if (value < 0) return 0.0;
  if (value > 1) return 1.0;
  return value;
}

Size clampNonNegativeSizeFinite(Size size) {
  return Size(
    clampNonNegativeFinite(size.width),
    clampNonNegativeFinite(size.height),
  );
}

Offset sanitizeFiniteOffset(Offset value) {
  return Offset(
    sanitizeFinite(value.dx, fallback: 0.0),
    sanitizeFinite(value.dy, fallback: 0.0),
  );
}
