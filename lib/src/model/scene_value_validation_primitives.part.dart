part of 'scene_value_validation.dart';

void sceneValidateFiniteDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePrimitiveBoundary(
    value,
    field: field,
    onError: onError,
    validate: (value, {required name}) =>
        validatedRequireFiniteDouble(value, name: name),
  );
}

void sceneValidateNonNegativeDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePrimitiveBoundary(
    value,
    field: field,
    onError: onError,
    validate: (value, {required name}) =>
        NonNegativeFiniteDoubleValue.of(value, name: name),
  );
}

void sceneValidatePositiveDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePrimitiveBoundary(
    value,
    field: field,
    onError: onError,
    validate: (value, {required name}) =>
        PositiveFiniteDoubleValue.of(value, name: name),
  );
}

void sceneValidateClamped01Double(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePrimitiveBoundary(
    value,
    field: field,
    onError: onError,
    validate: (value, {required name}) => OpacityValue.of(value, name: name),
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
  _sceneValidatePrimitiveBoundary(
    value,
    field: field,
    onError: onError,
    validate: (value, {required name}) =>
        FiniteOffsetValue.of(value, name: name),
  );
}

void sceneValidateNonNegativeSize(
  Size value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateFields<double>(
    <_SceneValidationField<double>>[
      (value: value.width, field: '$field.w'),
      (value: value.height, field: '$field.h'),
    ],
    onError: onError,
    validateValue: sceneValidateNonNegativeDouble,
  );
}

void sceneValidateFiniteTransform2D(
  Transform2D value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateFields<double>(
    <_SceneValidationField<double>>[
      (value: value.a, field: '$field.a'),
      (value: value.b, field: '$field.b'),
      (value: value.c, field: '$field.c'),
      (value: value.d, field: '$field.d'),
      (value: value.tx, field: '$field.tx'),
      (value: value.ty, field: '$field.ty'),
    ],
    onError: onError,
    validateValue: sceneValidateFiniteDouble,
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
  _sceneValidatePrimitiveBoundary(
    value,
    field: field,
    onError: onError,
    validate: (value, {required name}) =>
        SvgPathDataValue.of(value, name: name),
  );
}

void _sceneValidatePrimitiveBoundary<T>(
  T value, {
  required String field,
  required SceneValidationErrorReporter onError,
  required void Function(T value, {required String name}) validate,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => validate(value, name: field),
  );
}

void _sceneValidateFields<T>(
  List<_SceneValidationField<T>> values, {
  required SceneValidationErrorReporter onError,
  required _SceneValueValidator<T> validateValue,
}) {
  for (final entry in values) {
    validateValue(entry.value, field: entry.field, onError: onError);
  }
}

Never _sceneValidationFail({
  required SceneValidationErrorReporter onError,
  required Object? value,
  required String field,
  required String message,
}) {
  return onError(value: value, field: field, message: message);
}
