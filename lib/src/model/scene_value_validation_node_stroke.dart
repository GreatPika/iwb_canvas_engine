import 'dart:ui';

import '../contract/scene_contract_limits.dart';
import '../contract/scene_validation_diagnostics.dart';
import '../contract/snapshot.dart';
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
  if (points.length > kMaxStrokePointsPerNode) {
    onError(
      field: field,
      value: points,
      diagnostic: SceneDataDiagnosticDescriptor.maxPoints(
        maxPoints: kMaxStrokePointsPerNode,
      ),
    );
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
