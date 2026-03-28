import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';

RectNodeSchemaFields rectNodeSchemaFieldsFromSnapshot(RectNodeSnapshot rect) {
  return rectNodeSchemaFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNodeSchemaFields rectNodeSchemaFieldsFromSpec(RectNodeSpec rect) {
  return rectNodeSchemaFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNodeSchemaFields rectNodeSchemaFieldsFromNode(RectNode rect) {
  return rectNodeSchemaFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNode rectNodeFromSnapshot(RectNodeSnapshot rect, int instanceRevision) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: rect,
        instanceRevision: instanceRevision,
        extractFields: rectNodeSchemaFieldsFromSnapshot,
        buildNode: rectNodeFromSchema,
      )
      as RectNode;
}

RectNode rectNodeFromSpec(
  RectNodeSpec rect,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: rect,
        runtimeContext: runtimeContext,
        extractFields: rectNodeSchemaFieldsFromSpec,
        buildNode: rectNodeFromSchema,
      )
      as RectNode;
}

RectNode rectNodeFromSchema({
  required RuntimeNodeCommonFields common,
  required RectNodeSchemaFields fields,
}) {
  return RectNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
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

RectNodeSnapshot rectSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return rectNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
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
