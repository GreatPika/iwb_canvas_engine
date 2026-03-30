import 'dart:ui';

import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidateRectNodeSnapshot(
  RectNodeSnapshot rect, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateRectNodeFields(
    size: rect.size,
    strokeWidth: rect.strokeWidth,
    field: field,
    onError: onError,
  );
}

void sceneValidateRectNode(
  RectNode rect, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateRectNodeFields(
    size: rect.size,
    strokeWidth: rect.strokeWidth,
    field: field,
    onError: onError,
  );
}

void _sceneValidateRectNodeFields({
  required Size size,
  required double strokeWidth,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonNegativeSize(size, field: '$field.size', onError: onError);
  sceneValidateNonNegativeDouble(
    strokeWidth,
    field: '$field.strokeWidth',
    onError: onError,
  );
}
