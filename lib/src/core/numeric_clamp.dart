/// Numeric clamping helpers for runtime safety.
///
/// Note: JSON import/export applies stricter validation. These helpers exist to
/// make rendering, bounds, and hit-testing robust against invalid runtime
/// values (e.g. negative thickness) without throwing.
library;

double clampNonNegative(double value) => value < 0 ? 0.0 : value;

