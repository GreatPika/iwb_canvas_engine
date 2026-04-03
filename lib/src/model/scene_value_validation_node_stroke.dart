import 'dart:ui';

import '../contract/snapshot.dart';
import '../contract/scene_model_invariants.dart';
import '../core/nodes.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidateStrokeNodeSnapshot(
  StrokeNodeSnapshot stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePoints(stroke.points, field: '$field.points', onError: onError);
  sceneValidatePositiveDouble(
    stroke.thickness,
    field: '$field.thickness',
    onError: onError,
  );
}

void sceneValidateStrokeNode(
  StrokeNode stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePoints(
    stroke.points,
    field: '$field.localPoints',
    onError: onError,
  );
  sceneValidatePositiveDouble(
    stroke.thickness,
    field: '$field.thickness',
    onError: onError,
  );
}

void _sceneValidatePoints(
  List<Offset> points, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  final limitMessage = sceneStrokePointCountViolationMessage(points.length);
  if (limitMessage != null) {
    onError(field: field, value: points, message: 'Field $field $limitMessage');
  }
  sceneValidateFields<Offset>(
    List<SceneValidationField<Offset>>.generate(
      points.length,
      (index) => (value: points[index], field: '$field[$index]'),
    ),
    onError: onError,
    validateValue: sceneValidateFiniteOffset,
  );
}
