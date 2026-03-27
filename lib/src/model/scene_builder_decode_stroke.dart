import 'dart:ui';

import '../contract/internal/node_boundary_schema.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import '../contract/validated/finite_offset_value.dart';
import '../contract/validated/validated_value_support.dart';
import '../core/scene_limits.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

StrokeNodeSnapshot sceneBuilderDecodeStrokeSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeStrokeFields(json, nodePath: nodePath);
  return strokeNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    pointsRevision: fields.pointsRevision,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

StrokeNodeSnapshotSchemaFields _decodeStrokeFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: _decodeStrokePoints(json, nodePath: nodePath),
    pointsRevision: 0,
    thickness: validatedRequireJsonPositiveFiniteDouble(
      sceneBuilderRequireField(json, 'thickness', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'thickness'),
      fieldName: 'thickness',
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
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: pointsPath,
      message:
          'Field localPoints must contain at most $kMaxStrokePointsPerNode points.',
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
