import '../contract/internal/node_boundary_schema.dart';
import '../contract/snapshot.dart';
import '../contract/validated/svg_path_data_value.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

PathNodeSnapshot sceneBuilderDecodePathSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodePathFields(json, nodePath: nodePath);
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

PathNodeSchemaFields _decodePathFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return pathNodeSchemaFieldsFromValidated((
    svgPathData: SvgPathDataValue.fromJson(
      sceneBuilderRequireTypedField<String>(
        json,
        'svgPathData',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: sceneBuilderPathAt(nodePath, 'svgPathData'),
      fieldName: 'svgPathData',
    ).value,
    fillColor: sceneBuilderOptionalColor(
      json,
      'fillColor',
      pathPrefix: nodePath,
    ),
    strokeColor: sceneBuilderOptionalColor(
      json,
      'strokeColor',
      pathPrefix: nodePath,
    ),
    strokeWidth: validatedRequireJsonNonNegativeFiniteDouble(
      sceneBuilderRequireField(json, 'strokeWidth', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'strokeWidth'),
      fieldName: 'strokeWidth',
    ),
    fillRule: sceneBuilderParsePathFillRule(
      sceneBuilderRequireTypedField<String>(
        json,
        'fillRule',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      pathPrefix: nodePath,
    ),
  ));
}
