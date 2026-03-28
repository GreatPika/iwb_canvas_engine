import '../contract/internal/node_boundary_schema.dart';
import '../contract/snapshot.dart';
import '../contract/validated/image_id_value.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

ImageNodeSnapshot sceneBuilderDecodeImageSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeImageFields(json, nodePath: nodePath);
  return imageNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
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
