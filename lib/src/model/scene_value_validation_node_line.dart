import 'dart:ui';

import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidateLineNodeSnapshot(
  LineNodeSnapshot line, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateLineNodeFields(
    start: line.start,
    startField: '$field.start',
    end: line.end,
    endField: '$field.end',
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
}
