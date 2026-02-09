import 'dart:ui';

import 'numeric_clamp.dart';

/// Default scene-space step used by input decimation.
const double kInputDecimationMinStepScene = 0.75;

/// Returns squared Euclidean distance between [left] and [right].
double squaredDistanceBetween(Offset left, Offset right) {
  final delta = right - left;
  return delta.dx * delta.dx + delta.dy * delta.dy;
}

/// Returns true when distance between [left] and [right] is <= [threshold].
bool isDistanceAtMost(Offset left, Offset right, double threshold) {
  final safeThreshold = clampNonNegativeFinite(threshold);
  return squaredDistanceBetween(left, right) <= safeThreshold * safeThreshold;
}

/// Returns true when distance between [left] and [right] is >= [threshold].
bool isDistanceAtLeast(Offset left, Offset right, double threshold) {
  final safeThreshold = clampNonNegativeFinite(threshold);
  return squaredDistanceBetween(left, right) >= safeThreshold * safeThreshold;
}

/// Returns true when distance between [left] and [right] is > [threshold].
bool isDistanceGreaterThan(Offset left, Offset right, double threshold) {
  final safeThreshold = clampNonNegativeFinite(threshold);
  return squaredDistanceBetween(left, right) > safeThreshold * safeThreshold;
}
