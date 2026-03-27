import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';

PathNodeSchemaFields pathNodeSchemaFieldsFromSnapshot(PathNodeSnapshot path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields pathNodeSchemaFieldsFromSpec(PathNodeSpec path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields pathNodeSchemaFieldsFromNode(PathNode path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNode pathNodeFromSnapshot(PathNodeSnapshot path, int instanceRevision) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: path,
        instanceRevision: instanceRevision,
        extractFields: pathNodeSchemaFieldsFromSnapshot,
        buildNode: pathNodeFromSchema,
      )
      as PathNode;
}

PathNode pathNodeFromSpec(
  PathNodeSpec path,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: path,
        runtimeContext: runtimeContext,
        extractFields: pathNodeSchemaFieldsFromSpec,
        buildNode: pathNodeFromSchema,
      )
      as PathNode;
}

PathNode pathNodeFromSchema({
  required RuntimeNodeCommonFields common,
  required PathNodeSchemaFields fields,
}) {
  return PathNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
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

PathNodeSnapshot pathSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return pathNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
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
