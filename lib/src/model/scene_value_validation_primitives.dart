import 'dart:ui';

import '../contract/scene_data_exception.dart';
import '../contract/transform2d.dart';
import '../contract/validated/finite_offset_value.dart';
import '../contract/validated/non_negative_finite_double_value.dart';
import '../contract/validated/opacity_value.dart';
import '../contract/validated/positive_finite_double_value.dart';
import '../contract/validated/svg_path_data_value.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_value_validation_support.dart';

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
  sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeAtLeast(limit: 0),
  );
}

void sceneValidatePositiveInt(
  int value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value > 0) return;
  sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeGreaterThan(limit: 0),
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
  sceneValidateFields<double>(
    <SceneValidationField<double>>[
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
  sceneValidateFields<double>(
    <SceneValidationField<double>>[
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
    sceneValidationFail(
      onError: onError,
      value: value.toJsonMap(),
      field: field,
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeInvertible(),
    );
  }
}

void sceneValidateNonEmptyList(
  List<Object?> values, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (values.isNotEmpty) return;
  sceneValidationFail(
    onError: onError,
    value: values,
    field: field,
    diagnostic: SceneDataDiagnosticDescriptor.fieldMustNotBeEmpty(),
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
  sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => validate(value, name: field),
  );
}
