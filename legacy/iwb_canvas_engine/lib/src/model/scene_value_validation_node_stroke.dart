import 'dart:ui';

import '../contract/scene_validation_diagnostics.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import '../core/scene_limits.dart';
import 'scene_validation_path_surface.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';
import 'scene_value_validation_vector_width.dart';

void sceneValidateStrokeNodeSnapshot(
  StrokeNodeSnapshot stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
  SceneValidationPathSurface pathSurface = SceneValidationPathSurface.snapshot,
}) {
  _sceneValidateStrokeNodeFields(
    points: stroke.points,
    pointsField: sceneValidationStrokePointsField(pathSurface, field: field),
    thickness: stroke.thickness,
    field: field,
    onError: onError,
  );
}

void sceneValidateStrokeNode(
  StrokeNode stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateStrokeNodeFields(
    points: stroke.points,
    pointsField: '$field.localPoints',
    thickness: stroke.thickness,
    field: field,
    onError: onError,
  );
}

void sceneValidateStrokeNodeSnapshotBacking(
  StrokeNodeSnapshotBacking stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
  SceneValidationPathSurface pathSurface = SceneValidationPathSurface.snapshot,
}) {
  _sceneValidateStrokeNodeFields(
    points: stroke.points,
    pointsField: sceneValidationStrokePointsField(pathSurface, field: field),
    thickness: stroke.thickness,
    field: field,
    onError: onError,
  );
}

void _sceneValidateStrokeNodeFields({
  required List<Offset> points,
  required String pointsField,
  required double thickness,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePoints(points, field: pointsField, onError: onError);
  sceneValidatePositiveVectorWidth(
    thickness,
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
