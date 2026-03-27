import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';

ImageNodeSchemaFields imageNodeSchemaFieldsFromSnapshot(
  ImageNodeSnapshot image,
) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNodeSchemaFields imageNodeSchemaFieldsFromSpec(ImageNodeSpec image) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNodeSchemaFields imageNodeSchemaFieldsFromNode(ImageNode image) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNode imageNodeFromSnapshot(ImageNodeSnapshot image, int instanceRevision) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: image,
        instanceRevision: instanceRevision,
        extractFields: imageNodeSchemaFieldsFromSnapshot,
        buildNode: imageNodeFromSchema,
      )
      as ImageNode;
}

ImageNode imageNodeFromSpec(
  ImageNodeSpec image,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: image,
        runtimeContext: runtimeContext,
        extractFields: imageNodeSchemaFieldsFromSpec,
        buildNode: imageNodeFromSchema,
      )
      as ImageNode;
}

ImageNode imageNodeFromSchema({
  required RuntimeNodeCommonFields common,
  required ImageNodeSchemaFields fields,
}) {
  return ImageNode(
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

ImageNodeSnapshot imageSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required ImageNodeSchemaFields fields,
}) {
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
