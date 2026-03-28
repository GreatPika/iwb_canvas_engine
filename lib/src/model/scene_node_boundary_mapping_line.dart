import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';

LineNodeSchemaFields lineNodeSchemaFieldsFromSnapshot(LineNodeSnapshot line) {
  return lineNodeSchemaFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNodeSchemaFields lineNodeSchemaFieldsFromSpec(LineNodeSpec line) {
  return lineNodeSchemaFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNodeSchemaFields lineNodeSchemaFieldsFromNode(LineNode line) {
  return lineNodeSchemaFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNode lineNodeFromSnapshot(LineNodeSnapshot line, int instanceRevision) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: line,
        instanceRevision: instanceRevision,
        extractFields: lineNodeSchemaFieldsFromSnapshot,
        buildNode: lineNodeFromSchema,
      )
      as LineNode;
}

LineNode lineNodeFromSpec(
  LineNodeSpec line,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: line,
        runtimeContext: runtimeContext,
        extractFields: lineNodeSchemaFieldsFromSpec,
        buildNode: lineNodeFromSchema,
      )
      as LineNode;
}

LineNode lineNodeFromSchema({
  required RuntimeNodeCommonFields common,
  required LineNodeSchemaFields fields,
}) {
  return LineNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    start: fields.start,
    end: fields.end,
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

LineNodeSnapshotBacking lineSnapshotBackingFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required LineNodeSchemaFields fields,
}) {
  return lineNodeSnapshotBackingFromValidated(common: common, fields: fields);
}
