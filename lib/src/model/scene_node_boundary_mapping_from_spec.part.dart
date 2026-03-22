part of 'scene_node_boundary_mapping.dart';

SceneNode _nodeFromSpecViaBoundarySchema<SpecT extends NodeSpec, FieldsT>({
  required SpecT spec,
  required _RuntimeNodeCommonFields Function(NodeSpecCommonSchemaFields common)
  buildCommon,
  required FieldsT Function(SpecT spec) extractFields,
  required _SceneNodeFromSchema<FieldsT> buildNode,
}) {
  final common = buildCommon(_specCommonFromNodeSpec(spec));
  final fields = extractFields(spec);
  return buildNode(common: common, fields: fields);
}
