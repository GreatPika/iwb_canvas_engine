part of 'scene_node_boundary_mapping.dart';

SceneNode
_nodeFromSnapshotViaBoundarySchema<SnapshotT extends NodeSnapshot, FieldsT>({
  required SnapshotT snapshot,
  required int instanceRevision,
  required FieldsT Function(SnapshotT snapshot) extractFields,
  required _SceneNodeFromSchema<FieldsT> buildNode,
}) {
  final common = _runtimeCommonFromSnapshot(
    _snapshotCommonFromNodeSnapshot(snapshot),
    instanceRevision: instanceRevision,
  );
  final fields = extractFields(snapshot);
  return buildNode(common: common, fields: fields);
}
