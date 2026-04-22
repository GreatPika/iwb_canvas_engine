import 'dart:ui';

import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import '../core/scene_limits.dart';
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

void sceneValidateRectNodeSnapshotBacking(
  RectNodeSnapshotBacking rect, {
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
  sceneValidateDoubleInRange(
    size.width,
    field: '$field.size.w',
    min: 0,
    max: sceneSizeMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    size.height,
    field: '$field.size.h',
    min: 0,
    max: sceneSizeMax,
    onError: onError,
  );
  sceneValidateNonNegativeDouble(
    strokeWidth,
    field: '$field.strokeWidth',
    onError: onError,
  );
  sceneValidateDoubleInRange(
    strokeWidth,
    field: '$field.strokeWidth',
    min: 0,
    max: sceneThicknessMax,
    onError: onError,
  );
}
