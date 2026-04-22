import 'dart:ui';

import '../contract/snapshot.dart';
import '../core/nodes.dart';
import '../core/scene_limits.dart';
import 'scene_validation_path_surface.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidateLineNodeSnapshot(
  LineNodeSnapshot line, {
  required String field,
  required SceneValidationErrorReporter onError,
  SceneValidationPathSurface pathSurface = SceneValidationPathSurface.snapshot,
}) {
  _sceneValidateLineNodeFields(
    start: line.start,
    startField: sceneValidationLineStartField(pathSurface, field: field),
    end: line.end,
    endField: sceneValidationLineEndField(pathSurface, field: field),
    thickness: line.thickness,
    field: field,
    onError: onError,
  );
}

void sceneValidateLineNode(
  LineNode line, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateLineNodeFields(
    start: line.start,
    startField: '$field.localA',
    end: line.end,
    endField: '$field.localB',
    thickness: line.thickness,
    field: field,
    onError: onError,
  );
}

void _sceneValidateLineNodeFields({
  required Offset start,
  required String startField,
  required Offset end,
  required String endField,
  required double thickness,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteOffset(start, field: startField, onError: onError);
  sceneValidateFiniteOffset(end, field: endField, onError: onError);
  sceneValidatePositiveDouble(
    thickness,
    field: '$field.thickness',
    onError: onError,
  );
  sceneValidateDoubleInRange(
    thickness,
    field: '$field.thickness',
    min: 0,
    max: sceneThicknessMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    start.dx,
    field: '$startField.x',
    min: sceneCoordMin,
    max: sceneCoordMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    start.dy,
    field: '$startField.y',
    min: sceneCoordMin,
    max: sceneCoordMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    end.dx,
    field: '$endField.x',
    min: sceneCoordMin,
    max: sceneCoordMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    end.dy,
    field: '$endField.y',
    min: sceneCoordMin,
    max: sceneCoordMax,
    onError: onError,
  );
}
