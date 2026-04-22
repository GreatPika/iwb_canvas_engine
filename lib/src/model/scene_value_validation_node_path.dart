import '../contract/snapshot.dart';
import '../core/scene_limits.dart';
import '../core/nodes.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidatePathNodeSnapshot(
  PathNodeSnapshot path, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePathNodeFields(
    svgPathData: path.svgPathData,
    strokeWidth: path.strokeWidth,
    field: field,
    onError: onError,
  );
}

void sceneValidatePathNode(
  PathNode path, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePathNodeFields(
    svgPathData: path.svgPathData,
    strokeWidth: path.strokeWidth,
    field: field,
    onError: onError,
  );
}

void _sceneValidatePathNodeFields({
  required String svgPathData,
  required double strokeWidth,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateSvgPathData(
    svgPathData,
    field: '$field.svgPathData',
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
