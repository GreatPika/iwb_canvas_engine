part of 'scene_node_boundary_mapping.dart';

NodeSnapshot _nodeSnapshotFromNodeViaBoundarySchema<
  NodeT extends SceneNode,
  FieldsT,
  SnapshotT extends NodeSnapshot
>({
  required NodeT node,
  required FieldsT Function(NodeT node) extractFields,
  required _NodeSnapshotFromSchema<FieldsT, SnapshotT> buildSnapshot,
}) {
  final common = _snapshotCommonFromSceneNode(node);
  final fields = extractFields(node);
  return buildSnapshot(common: common, fields: fields);
}
