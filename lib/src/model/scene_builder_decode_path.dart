import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/validated/svg_path_data_value.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

PathNodeSnapshotBacking sceneBuilderDecodePathSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodePathFields(json, nodePath: nodePath);
  return pathNodeSnapshotBackingFromValidated(common: common, fields: fields);
}

PathNodeSchemaFields _decodePathFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return pathNodeSchemaFieldsFromValidated((
    svgPathData: sceneBuilderRequireValidatedField(
      json,
      'svgPathData',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          SvgPathDataValue.fromJson(
            value,
            path: path,
            fieldName: fieldName,
          ).value,
    ),
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
    strokeWidth: sceneBuilderRequireValidatedField(
      json,
      'strokeWidth',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonNonNegativeFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    fillRule: sceneBuilderParsePathFillRule(
      sceneBuilderRequireStringField(json, 'fillRule', pathPrefix: nodePath),
      pathPrefix: nodePath,
    ),
  ));
}
