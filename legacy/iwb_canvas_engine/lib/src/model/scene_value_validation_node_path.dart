import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';
import 'scene_value_validation_vector_width.dart';

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

void sceneValidatePathNodeSnapshotBacking(
  PathNodeSnapshotBacking path, {
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
  sceneValidateNonNegativeVectorWidth(
    strokeWidth,
    field: '$field.strokeWidth',
    onError: onError,
  );
}
