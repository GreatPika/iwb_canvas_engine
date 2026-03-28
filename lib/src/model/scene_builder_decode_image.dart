import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/validated/image_id_value.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

ImageNodeSnapshotBacking sceneBuilderDecodeImageSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeImageFields(json, nodePath: nodePath);
  return imageNodeSnapshotBackingFromValidated(common: common, fields: fields);
}

ImageNodeSchemaFields _decodeImageFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return imageNodeSchemaFieldsFromValidated((
    imageId: ImageIdValue.fromJson(
      sceneBuilderRequireField(json, 'imageId', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'imageId'),
      fieldName: 'imageId',
    ).value,
    size: sceneBuilderRequireSize(json, 'size', pathPrefix: nodePath),
    naturalSize: sceneBuilderOptionalSizeMap(
      json,
      'naturalSize',
      pathPrefix: nodePath,
    ),
  ));
}
