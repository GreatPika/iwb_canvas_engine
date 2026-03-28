import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

RectNodeSnapshotBacking sceneBuilderDecodeRectSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeRectFields(json, nodePath: nodePath);
  return rectNodeSnapshotBackingFromValidated(common: common, fields: fields);
}

RectNodeSchemaFields _decodeRectFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return rectNodeSchemaFieldsFromValidated((
    size: sceneBuilderRequireSize(json, 'size', pathPrefix: nodePath),
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
  ));
}
