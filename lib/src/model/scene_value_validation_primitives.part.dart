part of 'scene_value_validation.dart';

void sceneValidateFiniteDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value.isFinite) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be finite.',
  );
}

void sceneValidateNonNegativeDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value, field: field, onError: onError);
  if (value >= 0) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be >= 0.',
  );
}

void sceneValidatePositiveDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value, field: field, onError: onError);
  if (value > 0) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be > 0.',
  );
}

void sceneValidateClamped01Double(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value, field: field, onError: onError);
  if (value >= 0 && value <= 1) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be within [0,1].',
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
  sceneValidateFiniteDouble(value.dx, field: '$field.dx', onError: onError);
  sceneValidateFiniteDouble(value.dy, field: '$field.dy', onError: onError);
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
  sceneValidateFiniteDouble(value.a, field: '$field.a', onError: onError);
  sceneValidateFiniteDouble(value.b, field: '$field.b', onError: onError);
  sceneValidateFiniteDouble(value.c, field: '$field.c', onError: onError);
  sceneValidateFiniteDouble(value.d, field: '$field.d', onError: onError);
  sceneValidateFiniteDouble(value.tx, field: '$field.tx', onError: onError);
  sceneValidateFiniteDouble(value.ty, field: '$field.ty', onError: onError);
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
  if (value.trim().isEmpty) {
    _sceneValidationFail(
      onError: onError,
      value: value,
      field: field,
      message: 'must not be empty.',
    );
  }
  try {
    parseSvgPathData(value);
  } catch (_) {
    _sceneValidationFail(
      onError: onError,
      value: value,
      field: field,
      message: 'must be valid SVG path data.',
    );
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
