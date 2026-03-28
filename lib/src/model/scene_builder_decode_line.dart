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
    start: validatedRequireJsonFiniteOffset(
      sceneBuilderRequireField(json, 'localA', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'localA'),
      fieldName: 'localA',
    ),
    end: validatedRequireJsonFiniteOffset(
      sceneBuilderRequireField(json, 'localB', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'localB'),
      fieldName: 'localB',
    ),
    thickness: validatedRequireJsonPositiveFiniteDouble(
      sceneBuilderRequireField(json, 'thickness', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'thickness'),
      fieldName: 'thickness',
    ),
    color: sceneBuilderDecodeRequiredColor(json, 'color', pathPrefix: nodePath),
  ));
}
