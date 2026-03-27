import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';

StrokeNodeSnapshotSchemaFields strokeNodeSchemaFieldsFromSnapshot(
  StrokeNodeSnapshot stroke,
) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: stroke.points,
    pointsRevision: stroke.pointsRevision,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNodeSpecSchemaFields strokeNodeSchemaFieldsFromSpec(
  StrokeNodeSpec stroke,
) {
  return NodeBoundarySchema.strokeSpecFieldsFromValidated((
    points: stroke.points,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNodeSnapshotSchemaFields strokeNodeSchemaFieldsFromNode(
  StrokeNode stroke,
) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: stroke.points,
    pointsRevision: stroke.pointsRevision,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNode strokeNodeFromSnapshot(
  StrokeNodeSnapshot stroke,
  int instanceRevision,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: stroke,
        instanceRevision: instanceRevision,
        extractFields: strokeNodeSchemaFieldsFromSnapshot,
        buildNode: strokeNodeFromSnapshotSchema,
      )
      as StrokeNode;
}

StrokeNode strokeNodeFromSpec(
  StrokeNodeSpec stroke,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: stroke,
        runtimeContext: runtimeContext,
        extractFields: strokeNodeSchemaFieldsFromSpec,
        buildNode: strokeNodeFromSpecSchema,
      )
      as StrokeNode;
}

StrokeNode strokeNodeFromSnapshotSchema({
  required RuntimeNodeCommonFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
  return StrokeNode(
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

StrokeNode strokeNodeFromSpecSchema({
  required RuntimeNodeCommonFields common,
  required StrokeNodeSpecSchemaFields fields,
}) {
  return StrokeNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
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

StrokeNodeSnapshot strokeSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
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
