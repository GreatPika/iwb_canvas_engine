import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../core/nodes.dart';

enum TextNodeSnapshotSizePolicy { preserveBoundarySize, recomputeFromLayout }

typedef RuntimeNodeCommonFields = ({
  NodeId id,
  int instanceRevision,
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef SpecRuntimeNodeContext = ({NodeId fallbackId, int instanceRevision});

typedef SceneNodeFromSchema<FieldsT> =
    SceneNode Function({
      required RuntimeNodeCommonFields common,
      required FieldsT fields,
    });

typedef NodeSnapshotFromSchema<FieldsT, SnapshotT extends NodeSnapshot> =
    SnapshotT Function({
      required NodeSnapshotCommonSchemaFields common,
      required FieldsT fields,
    });

typedef NodeSnapshotBackingFromSchema<
  FieldsT,
  SnapshotBackingT extends NodeSnapshotBacking
> =
    SnapshotBackingT Function({
      required NodeSnapshotCommonSchemaFields common,
      required FieldsT fields,
    });

NodeSnapshotCommonSchemaFields snapshotCommonFromNodeSnapshot(
  NodeSnapshot node,
) {
  return snapshotCommonSchemaFieldsFromValidated((
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    opacity: node.opacity,
    hitPadding: node.hitPadding,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    isLocked: node.isLocked,
    isDeletable: node.isDeletable,
    isTransformable: node.isTransformable,
  ));
}

NodeSpecCommonSchemaFields specCommonFromNodeSpec(NodeSpec spec) {
  return specCommonSchemaFieldsFromValidated((
    id: spec.id,
    transform: spec.transform,
    opacity: spec.opacity,
    hitPadding: spec.hitPadding,
    isVisible: spec.isVisible,
    isSelectable: spec.isSelectable,
    isLocked: spec.isLocked,
    isDeletable: spec.isDeletable,
    isTransformable: spec.isTransformable,
  ));
}

NodeSnapshotCommonSchemaFields snapshotCommonFromSceneNode(SceneNode node) {
  return snapshotCommonSchemaFieldsFromValidated((
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    opacity: node.opacity,
    hitPadding: node.hitPadding,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    isLocked: node.isLocked,
    isDeletable: node.isDeletable,
    isTransformable: node.isTransformable,
  ));
}

RuntimeNodeCommonFields runtimeCommonFromSnapshot(
  NodeSnapshotCommonSchemaFields common, {
  required int instanceRevision,
}) {
  return (
    id: common.id,
    instanceRevision: instanceRevision,
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

RuntimeNodeCommonFields runtimeCommonFromSpec(
  NodeSpecCommonSchemaFields common, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return (
    id: common.id ?? fallbackId,
    instanceRevision: instanceRevision,
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

SceneNode
sceneNodeFromSnapshotViaSchema<SnapshotT extends NodeSnapshot, FieldsT>({
  required SnapshotT snapshot,
  required int instanceRevision,
  required FieldsT Function(SnapshotT snapshot) extractFields,
  required SceneNodeFromSchema<FieldsT> buildNode,
}) {
  final common = runtimeCommonFromSnapshot(
    snapshotCommonFromNodeSnapshot(snapshot),
    instanceRevision: instanceRevision,
  );
  final fields = extractFields(snapshot);
  return buildNode(common: common, fields: fields);
}

SceneNode sceneNodeFromSpecViaSchema<SpecT extends NodeSpec, FieldsT>({
  required SpecT spec,
  required SpecRuntimeNodeContext runtimeContext,
  required FieldsT Function(SpecT spec) extractFields,
  required SceneNodeFromSchema<FieldsT> buildNode,
}) {
  final common = runtimeCommonFromSpec(
    specCommonFromNodeSpec(spec),
    fallbackId: runtimeContext.fallbackId,
    instanceRevision: runtimeContext.instanceRevision,
  );
  final fields = extractFields(spec);
  return buildNode(common: common, fields: fields);
}

NodeSnapshotBacking sceneNodeSnapshotBackingFromViaSchema<
  NodeT extends SceneNode,
  FieldsT,
  SnapshotBackingT extends NodeSnapshotBacking
>({
  required NodeT node,
  required FieldsT Function(NodeT node) extractFields,
  required NodeSnapshotBackingFromSchema<FieldsT, SnapshotBackingT>
  buildSnapshotBacking,
}) {
  final common = snapshotCommonFromSceneNode(node);
  final fields = extractFields(node);
  return buildSnapshotBacking(common: common, fields: fields);
}
