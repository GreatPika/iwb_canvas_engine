import '../core/scene_limits.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidatePositiveVectorWidth(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateVectorWidth(
    value,
    field: field,
    allowZero: false,
    onError: onError,
  );
}

void sceneValidateNonNegativeVectorWidth(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateVectorWidth(
    value,
    field: field,
    allowZero: true,
    onError: onError,
  );
}

void _sceneValidateVectorWidth(
  double value, {
  required String field,
  required bool allowZero,
  required SceneValidationErrorReporter onError,
}) {
  if (allowZero) {
    sceneValidateNonNegativeDouble(value, field: field, onError: onError);
  } else {
    sceneValidatePositiveDouble(value, field: field, onError: onError);
  }
  sceneValidateDoubleInRange(
    value,
    field: field,
    min: 0,
    max: sceneThicknessMax,
    onError: onError,
  );
}
