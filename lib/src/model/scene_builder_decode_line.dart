import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

LineNodeSnapshotBacking sceneBuilderDecodeLineSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeLineFields(json, nodePath: nodePath);
  return lineNodeSnapshotBackingFromValidated(common: common, fields: fields);
}

LineNodeSchemaFields _decodeLineFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return lineNodeSchemaFieldsFromValidated((
    start: sceneBuilderRequireValidatedField(
      json,
      'localA',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonFiniteOffset(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    end: sceneBuilderRequireValidatedField(
      json,
      'localB',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonFiniteOffset(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    thickness: sceneBuilderRequireValidatedField(
      json,
      'thickness',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonPositiveFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    color: sceneBuilderDecodeRequiredColor(json, 'color', pathPrefix: nodePath),
  ));
}
