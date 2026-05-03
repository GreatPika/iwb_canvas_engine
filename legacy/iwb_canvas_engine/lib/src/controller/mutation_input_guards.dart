import 'dart:ui';

import '../contract/transform2d.dart';

void requireFiniteOffsetMutationInput(Offset value, {required String name}) {
  if (value.dx.isFinite && value.dy.isFinite) {
    return;
  }
  throw ArgumentError.value(value, name, 'Offset must be finite.');
}

void requireFiniteTransformMutationInput(
  Transform2D value, {
  required String name,
}) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      name,
      'Transform2D fields must be finite.',
    );
  }
  if (value.invert() == null) {
    throw ArgumentError.value(
      value.toJsonMap(),
      name,
      'Transform2D must be invertible (non-singular).',
    );
  }
}

void requireFinitePositiveMutationInput(double value, {required String name}) {
  if (value.isFinite && value > 0) {
    return;
  }
  throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
}
