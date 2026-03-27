import '../contract/internal/node_boundary_schema.dart';
import '../contract/snapshot.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

RectNodeSnapshot sceneBuilderDecodeRectSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeRectFields(json, nodePath: nodePath);
  return rectNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
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

RectNodeSchemaFields _decodeRectFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.rectFieldsFromValidated((
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
