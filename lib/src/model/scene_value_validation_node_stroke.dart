import 'dart:ui';

import '../contract/scene_validation_diagnostics.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import '../core/scene_limits.dart';
import 'scene_validation_path_surface.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidateStrokeNodeSnapshot(
  StrokeNodeSnapshot stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
  SceneValidationPathSurface pathSurface = SceneValidationPathSurface.snapshot,
}) {
  _sceneValidatePoints(
    stroke.points,
    field: sceneValidationStrokePointsField(pathSurface, field: field),
    onError: onError,
  );
  sceneValidatePositiveDouble(
    stroke.thickness,
    field: '$field.thickness',
    onError: onError,
  );
  sceneValidateDoubleInRange(
    stroke.thickness,
    field: '$field.thickness',
    min: 0,
    max: sceneThicknessMax,
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
  for (var index = 0; index < points.length; index++) {
    sceneValidateDoubleInRange(
      points[index].dx,
      field: '$field[$index].x',
      min: sceneCoordMin,
      max: sceneCoordMax,
      onError: onError,
    );
    sceneValidateDoubleInRange(
      points[index].dy,
      field: '$field[$index].y',
      min: sceneCoordMin,
      max: sceneCoordMax,
      onError: onError,
    );
  }
}
