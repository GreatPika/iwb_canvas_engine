part of 'scene_value_validation.dart';

void sceneValidateFiniteDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => validatedRequireFiniteDouble(value, name: field),
  );
}

void sceneValidateNonNegativeDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(value, name: field),
  );
}

void sceneValidatePositiveDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => PositiveFiniteDoubleValue.of(value, name: field),
  );
}

void sceneValidateClamped01Double(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => OpacityValue.of(value, name: field),
  );
}

void sceneValidateNonNegativeInt(
  int value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value >= 0) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be >= 0.',
  );
}

void sceneValidatePositiveInt(
  int value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value > 0) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be > 0.',
  );
}

void sceneValidateFiniteOffset(
  Offset value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => FiniteOffsetValue.of(value, name: field),
  );
}

void sceneValidateNonNegativeSize(
  Size value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonNegativeDouble(
    value.width,
    field: '$field.w',
    onError: onError,
  );
  sceneValidateNonNegativeDouble(
    value.height,
    field: '$field.h',
    onError: onError,
  );
}

void sceneValidateFiniteTransform2D(
  Transform2D value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.a',
    value: value.a,
    onError: onError,
    validate: () => validatedRequireFiniteDouble(value.a, name: '$field.a'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.b',
    value: value.b,
    onError: onError,
    validate: () => validatedRequireFiniteDouble(value.b, name: '$field.b'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.c',
    value: value.c,
    onError: onError,
    validate: () => validatedRequireFiniteDouble(value.c, name: '$field.c'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.d',
    value: value.d,
    onError: onError,
    validate: () => validatedRequireFiniteDouble(value.d, name: '$field.d'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.tx',
    value: value.tx,
    onError: onError,
    validate: () => validatedRequireFiniteDouble(value.tx, name: '$field.tx'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.ty',
    value: value.ty,
    onError: onError,
    validate: () => validatedRequireFiniteDouble(value.ty, name: '$field.ty'),
  );
  if (value.invert() == null) {
    _sceneValidationFail(
      onError: onError,
      value: value.toJsonMap(),
      field: field,
      message: 'must be invertible (non-singular).',
    );
  }
}

void sceneValidateNonEmptyList(
  List<Object?> values, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (values.isNotEmpty) return;
  _sceneValidationFail(
    onError: onError,
    value: values,
    field: field,
    message: 'must not be empty.',
  );
}

void sceneValidateSvgPathData(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => SvgPathDataValue.of(value, name: field),
  );
}

Never _sceneValidationFail({
  required SceneValidationErrorReporter onError,
  required Object? value,
  required String field,
  required String message,
}) {
  return onError(value: value, field: field, message: message);
}
