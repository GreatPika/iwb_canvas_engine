import '../contract/internal/snapshot_fast_path.dart';
import '../contract/validated/layer_id_value.dart';
import 'scene_builder_decode_node_family.dart';
import 'scene_builder_json_require.dart';
import 'scene_structural_limits.dart';

typedef DecodedSceneLayers = ({
  BackgroundLayerSnapshotBacking? backgroundLayer,
  List<ContentLayerSnapshotBacking> layers,
});

DecodedSceneLayers sceneBuilderDecodeSceneLayers(
  Map<String, Object?> json, {
  required void Function(String nodesPath) onNodeDecoded,
}) {
  return (
    backgroundLayer: _decodeOptionalBackgroundLayer(
      json,
      onNodeDecoded: onNodeDecoded,
    ),
    layers: _decodeContentLayers(json, onNodeDecoded: onNodeDecoded),
  );
}

BackgroundLayerSnapshotBacking? _decodeOptionalBackgroundLayer(
  Map<String, Object?> json, {
  required void Function(String nodesPath) onNodeDecoded,
}) {
  final backgroundLayerJson = json['backgroundLayer'];
  if (backgroundLayerJson == null) {
    return null;
  }
  return _decodeBackgroundLayer(
    sceneBuilderRequireObjectValue(
      backgroundLayerJson,
      path: 'backgroundLayer',
      objectName: 'Layer',
    ),
    layerPath: 'backgroundLayer',
    onNodeDecoded: onNodeDecoded,
  );
}

List<ContentLayerSnapshotBacking> _decodeContentLayers(
  Map<String, Object?> json, {
  required void Function(String nodesPath) onNodeDecoded,
}) {
  final layersJson = sceneBuilderRequireList(json, 'layers');
  sceneRequireContentLayerLimit(layersJson.length);
  final layers = <ContentLayerSnapshotBacking>[];
  for (var layerIndex = 0; layerIndex < layersJson.length; layerIndex++) {
    final layerPath = 'layers[$layerIndex]';
    layers.add(
      _decodeContentLayer(
        sceneBuilderRequireObjectValue(
          layersJson[layerIndex],
          path: layerPath,
          objectName: 'Layer',
        ),
        layerPath: layerPath,
        onNodeDecoded: onNodeDecoded,
      ),
    );
  }
  return layers;
}

BackgroundLayerSnapshotBacking _decodeBackgroundLayer(
  Map<String, Object?> json, {
  required String layerPath,
  required void Function(String nodesPath) onNodeDecoded,
}) {
  return backgroundLayerSnapshotBackingFromValidated(
    nodes: _decodeLayerNodes(
      json,
      layerPath: layerPath,
      onNodeDecoded: onNodeDecoded,
    ),
  );
}

ContentLayerSnapshotBacking _decodeContentLayer(
  Map<String, Object?> json, {
  required String layerPath,
  required void Function(String nodesPath) onNodeDecoded,
}) {
  return contentLayerSnapshotBackingFromValidated(
    id: _decodeLayerId(json, layerPath: layerPath),
    nodes: _decodeLayerNodes(
      json,
      layerPath: layerPath,
      onNodeDecoded: onNodeDecoded,
    ),
  );
}

String _decodeLayerId(Map<String, Object?> json, {required String layerPath}) {
  return sceneBuilderRequireValidatedField(
    json,
    'id',
    pathPrefix: layerPath,
    parse: (value, {required path, required fieldName}) =>
        LayerIdValue.fromJson(value, path: path, fieldName: path).value,
  );
}

List<NodeSnapshotBacking> _decodeLayerNodes(
  Map<String, Object?> json, {
  required String layerPath,
  required void Function(String nodesPath) onNodeDecoded,
}) {
  final nodesJson = sceneBuilderRequireList(
    json,
    'nodes',
    pathPrefix: layerPath,
  );
  final nodesPath = sceneBuilderPathAt(layerPath, 'nodes');
  final nodes = <NodeSnapshotBacking>[];
  for (var nodeIndex = 0; nodeIndex < nodesJson.length; nodeIndex++) {
    onNodeDecoded(nodesPath);
    final nodePath = sceneBuilderPathAt(nodesPath, '[$nodeIndex]');
    nodes.add(
      sceneBuilderDecodeNodeSnapshot(
        sceneBuilderRequireObjectValue(
          nodesJson[nodeIndex],
          path: nodePath,
          objectName: 'Node',
        ),
        nodePath: nodePath,
      ),
    );
  }
  return nodes;
}
