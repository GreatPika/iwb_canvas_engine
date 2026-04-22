import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
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

RectNodeSchemaFields rectNodeSchemaFieldsFromBacking(
  RectNodeSnapshotBacking rect,
) {
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

RectNode rectNodeFromSnapshotBacking(
  RectNodeSnapshotBacking rect,
  int instanceRevision,
) {
  return rectNodeFromSchema(
    common: runtimeCommonFromSnapshotBacking(
      rect,
      instanceRevision: instanceRevision,
    ),
    fields: rectNodeSchemaFieldsFromBacking(rect),
  );
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

RectNode cloneRuntimeRectNode(RectNode rect) {
  return RectNode(
    id: rect.id,
    instanceRevision: rect.instanceRevision,
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
    transform: rect.transform,
    opacity: rect.opacity,
    hitPadding: rect.hitPadding,
    isVisible: rect.isVisible,
    isSelectable: rect.isSelectable,
    isLocked: rect.isLocked,
    isDeletable: rect.isDeletable,
    isTransformable: rect.isTransformable,
  );
}

RectNodeSnapshotBacking rectSnapshotBackingFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return rectNodeSnapshotBackingFromValidated(common: common, fields: fields);
}
