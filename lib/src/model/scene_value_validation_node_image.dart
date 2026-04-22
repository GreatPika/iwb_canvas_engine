import 'dart:ui';

import '../contract/snapshot.dart';
import '../contract/validated/image_id_value.dart';
import '../core/scene_limits.dart';
import '../core/nodes.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidateImageNodeSnapshot(
  ImageNodeSnapshot image, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateImageNodeFields(
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
    field: field,
    onError: onError,
  );
}

void sceneValidateImageNode(
  ImageNode image, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateImageNodeFields(
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
    field: field,
    onError: onError,
  );
}

void _sceneValidateImageNodeFields({
  required String imageId,
  required Size size,
  required Size? naturalSize,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateArgumentBoundary(
    field: '$field.imageId',
    value: imageId,
    onError: onError,
    validate: () => ImageIdValue.of(imageId, name: '$field.imageId'),
  );
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

  if (naturalSize != null) {
    sceneValidateNonNegativeSize(
      naturalSize,
      field: '$field.naturalSize',
      onError: onError,
    );
    sceneValidateDoubleInRange(
      naturalSize.width,
      field: '$field.naturalSize.w',
      min: 0,
      max: sceneSizeMax,
      onError: onError,
    );
    sceneValidateDoubleInRange(
      naturalSize.height,
      field: '$field.naturalSize.h',
      min: 0,
      max: sceneSizeMax,
      onError: onError,
    );
  }
}
