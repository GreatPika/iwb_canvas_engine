import 'dart:ui';

import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/scene_contract_limits.dart';
import '../contract/scene_data_exception.dart';
import '../contract/validated/finite_offset_value.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

StrokeNodeSnapshotBacking sceneBuilderDecodeStrokeSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeStrokeFields(json, nodePath: nodePath);
  return strokeNodeSnapshotBackingFromValidated(common: common, fields: fields);
}

StrokeNodeSnapshotSchemaFields _decodeStrokeFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return strokeNodeSnapshotSchemaFieldsFromValidated((
    points: _decodeStrokePoints(json, nodePath: nodePath),
    thickness: sceneBuilderRequireValidatedField(
      json,
      'thickness',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonPositiveFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    color: sceneBuilderDecodeRequiredColor(json, 'color', pathPrefix: nodePath),
  ));
}

List<Offset> _decodeStrokePoints(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final pointsPath = sceneBuilderPathAt(nodePath, 'localPoints');
  final pointsJson = sceneBuilderRequireList(
    json,
    'localPoints',
    pathPrefix: nodePath,
  );
  if (pointsJson.length > kMaxStrokePointsPerNode) {
    throw SceneDataException.maxPoints(
      path: pointsPath,
      maxPoints: kMaxStrokePointsPerNode,
      source: pointsJson.length,
    );
  }
  final points = <Offset>[];
  for (var i = 0; i < pointsJson.length; i++) {
    points.add(
      FiniteOffsetValue.fromJson(
        pointsJson[i],
        path: sceneBuilderPathAt(pointsPath, '[$i]'),
        fieldName: sceneBuilderPathAt(pointsPath, '[$i]'),
      ).value,
    );
  }
  return points;
}
