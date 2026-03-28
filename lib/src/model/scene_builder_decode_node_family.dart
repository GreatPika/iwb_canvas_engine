import '../contract/internal/snapshot_fast_path.dart';
import '../core/nodes.dart';
import 'scene_builder_decode_image.dart';
import 'scene_builder_decode_line.dart';
import 'scene_builder_decode_node_common.dart';
import 'scene_builder_decode_path.dart';
import 'scene_builder_decode_rect.dart';
import 'scene_builder_decode_stroke.dart';
import 'scene_builder_decode_text.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

NodeSnapshotBacking sceneBuilderDecodeNodeSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final type = _decodeNodeType(json, nodePath: nodePath);
  final common = sceneBuilderDecodeNodeCommonFields(json, nodePath: nodePath);
  return switch (type) {
    NodeType.image => sceneBuilderDecodeImageSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.text => sceneBuilderDecodeTextSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.stroke => sceneBuilderDecodeStrokeSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.line => sceneBuilderDecodeLineSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.rect => sceneBuilderDecodeRectSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.path => sceneBuilderDecodePathSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
  };
}

NodeType _decodeNodeType(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return sceneBuilderParseNodeType(
    sceneBuilderRequireTypedField<String>(
      json,
      'type',
      pathPrefix: nodePath,
      typeLabel: 'string',
    ),
    pathPrefix: nodePath,
  );
}
