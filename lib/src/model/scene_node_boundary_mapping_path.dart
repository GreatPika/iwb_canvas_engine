import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';

PathNodeSchemaFields pathNodeSchemaFieldsFromSnapshot(PathNodeSnapshot path) {
  return pathNodeSchemaFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields pathNodeSchemaFieldsFromSpec(PathNodeSpec path) {
  return pathNodeSchemaFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields pathNodeSchemaFieldsFromNode(PathNode path) {
  return pathNodeSchemaFieldsFromValidated((
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

PathNode cloneRuntimePathNode(PathNode path) {
  return PathNode(
    id: path.id,
    instanceRevision: path.instanceRevision,
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
    transform: path.transform,
    opacity: path.opacity,
    hitPadding: path.hitPadding,
    isVisible: path.isVisible,
    isSelectable: path.isSelectable,
    isLocked: path.isLocked,
    isDeletable: path.isDeletable,
    isTransformable: path.isTransformable,
  );
}

PathNodeSnapshotBacking pathSnapshotBackingFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return pathNodeSnapshotBackingFromValidated(common: common, fields: fields);
}
