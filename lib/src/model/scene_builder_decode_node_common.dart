import '../contract/internal/node_boundary_schema.dart';
import '../contract/transform2d.dart';
import '../contract/validated/instance_revision_value.dart';
import '../contract/validated/node_id_value.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

NodeSnapshotCommonSchemaFields sceneBuilderDecodeNodeCommonFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final flags = _decodeNodeFlags(json, nodePath: nodePath);
  return NodeBoundarySchema.snapshotCommonFromValidated((
    id: _decodeNodeId(json, nodePath: nodePath),
    instanceRevision: _decodeNodeInstanceRevision(json, nodePath: nodePath),
    transform: _decodeNodeTransform(json, nodePath: nodePath),
    hitPadding: validatedRequireJsonNonNegativeFiniteDouble(
      sceneBuilderRequireField(json, 'hitPadding', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'hitPadding'),
      fieldName: 'hitPadding',
    ),
    opacity: validatedRequireJsonOpacity(
      sceneBuilderRequireField(json, 'opacity', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'opacity'),
      fieldName: 'opacity',
    ),
    isVisible: flags.isVisible,
    isSelectable: flags.isSelectable,
    isLocked: flags.isLocked,
    isDeletable: flags.isDeletable,
    isTransformable: flags.isTransformable,
  ));
}

({
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
})
_decodeNodeFlags(Map<String, Object?> json, {required String nodePath}) {
  return (
    isVisible: sceneBuilderRequireTypedField<bool>(
      json,
      'isVisible',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isSelectable: sceneBuilderRequireTypedField<bool>(
      json,
      'isSelectable',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isLocked: sceneBuilderRequireTypedField<bool>(
      json,
      'isLocked',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isDeletable: sceneBuilderRequireTypedField<bool>(
      json,
      'isDeletable',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isTransformable: sceneBuilderRequireTypedField<bool>(
      json,
      'isTransformable',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
  );
}

String _decodeNodeId(Map<String, Object?> json, {required String nodePath}) {
  return sceneBuilderRequireValidatedField(
    json,
    'id',
    pathPrefix: nodePath,
    parse: (value, {required path, required fieldName}) =>
        NodeIdValue.fromJson(value, path: path, fieldName: fieldName).value,
  );
}

int _decodeNodeInstanceRevision(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return sceneBuilderOptionalValidatedField(
        json,
        'instanceRevision',
        pathPrefix: nodePath,
        parse: (value, {required path, required fieldName}) =>
            InstanceRevisionValue.fromJson(
              value,
              path: path,
              fieldName: fieldName,
              allowZero: true,
            ).value,
      ) ??
      0;
}

Transform2D _decodeNodeTransform(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return sceneBuilderDecodeTransform2D(
    sceneBuilderRequireMap(json, 'transform', pathPrefix: nodePath),
    pathPrefix: sceneBuilderPathAt(nodePath, 'transform'),
  );
}
