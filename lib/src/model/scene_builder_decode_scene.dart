import 'dart:ui';

import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import '../contract/validated/layer_id_value.dart';
import '../contract/validated/validated_value_support.dart';
import '../core/scene_limits.dart';
import 'scene_builder_decode_node_family.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';
import 'scene_structural_limits.dart';

typedef DecodedScenePayload = ({
  CameraSnapshot camera,
  BackgroundSnapshot background,
  ScenePaletteSnapshot palette,
  BackgroundLayerSnapshot? backgroundLayer,
  List<ContentLayerSnapshot> layers,
});

SceneSnapshot sceneBuilderDecodeSceneSnapshotFromJson(
  Map<String, Object?> json,
) {
  _requireSupportedSchemaVersion(json);
  final payload = _decodeScenePayload(json);
  return sceneSnapshotFromValidated(
    backgroundLayer: payload.backgroundLayer,
    layers: payload.layers,
    camera: payload.camera,
    background: payload.background,
    palette: payload.palette,
  );
}

void _requireSupportedSchemaVersion(Map<String, Object?> json) {
  final version = sceneBuilderRequireValidatedField(
    json,
    'schemaVersion',
    parse: (value, {required path, required fieldName}) =>
        validatedRequireJsonInt(
          value,
          path: path,
          fieldName: fieldName,
          allowZero: false,
        ),
  );
  if (sceneSchemaVersionsRead.contains(version)) {
    return;
  }
  final expectedVersions = sceneSchemaVersionsRead.toList()
    ..sort((a, b) => a.compareTo(b));
  final expectedVersionsMessage = expectedVersions.join(', ');
  throw SceneDataException(
    code: SceneDataErrorCode.unsupportedSchemaVersion,
    path: 'schemaVersion',
    message:
        'Unsupported schemaVersion: $version. Expected one of: [$expectedVersionsMessage].',
  );
}

DecodedScenePayload _decodeScenePayload(Map<String, Object?> json) {
  var totalNodeCount = 0;
  void consumeNodeBudget(String path) {
    totalNodeCount = sceneConsumeNodeBudget(
      totalNodeCount: totalNodeCount,
      path: path,
    );
  }

  return (
    camera: _decodeCameraSnapshot(json),
    background: _decodeBackgroundSnapshot(json),
    palette: _decodePaletteSnapshot(json),
    backgroundLayer: _decodeOptionalBackgroundLayer(
      json,
      onNodeDecoded: consumeNodeBudget,
    ),
    layers: _decodeContentLayers(json, onNodeDecoded: consumeNodeBudget),
  );
}

CameraSnapshot _decodeCameraSnapshot(Map<String, Object?> json) {
  final cameraJson = sceneBuilderRequireMap(json, 'camera');
  return cameraSnapshotFromValidated(
    offset: Offset(
      validatedRequireJsonFiniteDouble(
        sceneBuilderRequireField(cameraJson, 'offsetX', pathPrefix: 'camera'),
        path: 'camera.offsetX',
        fieldName: 'offsetX',
      ),
      validatedRequireJsonFiniteDouble(
        sceneBuilderRequireField(cameraJson, 'offsetY', pathPrefix: 'camera'),
        path: 'camera.offsetY',
        fieldName: 'offsetY',
      ),
    ),
  );
}

BackgroundSnapshot _decodeBackgroundSnapshot(Map<String, Object?> json) {
  final backgroundJson = sceneBuilderRequireMap(json, 'background');
  final gridJson = sceneBuilderRequireMap(
    backgroundJson,
    'grid',
    pathPrefix: 'background',
  );
  return backgroundSnapshotFromValidated(
    color: sceneBuilderParseColor(
      sceneBuilderRequireTypedField<String>(
        backgroundJson,
        'color',
        pathPrefix: 'background',
        typeLabel: 'string',
      ),
      path: 'background.color',
    ),
    grid: gridSnapshotFromValidated(
      isEnabled: sceneBuilderRequireTypedField<bool>(
        gridJson,
        'enabled',
        pathPrefix: 'background.grid',
        typeLabel: 'bool',
      ),
      cellSize: validatedRequireJsonFiniteDouble(
        sceneBuilderRequireField(
          gridJson,
          'cellSize',
          pathPrefix: 'background.grid',
        ),
        path: 'background.grid.cellSize',
        fieldName: 'cellSize',
      ),
      color: sceneBuilderParseColor(
        sceneBuilderRequireTypedField<String>(
          gridJson,
          'color',
          pathPrefix: 'background.grid',
          typeLabel: 'string',
        ),
        path: 'background.grid.color',
      ),
    ),
  );
}

ScenePaletteSnapshot _decodePaletteSnapshot(Map<String, Object?> json) {
  final paletteJson = sceneBuilderRequireMap(json, 'palette');
  return scenePaletteSnapshotFromValidated(
    penColors: _decodePaletteColors(
      paletteJson,
      key: 'penColors',
      pathPrefix: 'palette',
    ),
    backgroundColors: _decodePaletteColors(
      paletteJson,
      key: 'backgroundColors',
      pathPrefix: 'palette',
    ),
    gridSizes: _decodePaletteGridSizes(paletteJson),
  );
}

List<Color> _decodePaletteColors(
  Map<String, Object?> paletteJson, {
  required String key,
  required String pathPrefix,
}) {
  final colorsJson = sceneBuilderRequireList(
    paletteJson,
    key,
    pathPrefix: pathPrefix,
    maxLength: kMaxPaletteItems,
  );
  final colorsPath = sceneBuilderPathAt(pathPrefix, key);
  final colors = <Color>[];
  for (var i = 0; i < colorsJson.length; i++) {
    final path = sceneBuilderPathAt(colorsPath, '[$i]');
    final value = sceneBuilderRequireStringValue(
      colorsJson[i],
      field: key,
      path: path,
    );
    colors.add(sceneBuilderParseColor(value, path: path));
  }
  return colors;
}

List<double> _decodePaletteGridSizes(Map<String, Object?> paletteJson) {
  final gridSizesJson = sceneBuilderRequireList(
    paletteJson,
    'gridSizes',
    pathPrefix: 'palette',
    maxLength: kMaxPaletteItems,
  );
  const gridSizesField = 'gridSizes';
  const gridSizesPath = 'palette.gridSizes';
  final gridSizes = <double>[];
  for (var i = 0; i < gridSizesJson.length; i++) {
    final path = sceneBuilderPathAt(gridSizesPath, '[$i]');
    gridSizes.add(
      sceneBuilderRequireDoubleValue(
        gridSizesJson[i],
        field: gridSizesField,
        path: path,
      ),
    );
  }
  return gridSizes;
}

BackgroundLayerSnapshot? _decodeOptionalBackgroundLayer(
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

List<ContentLayerSnapshot> _decodeContentLayers(
  Map<String, Object?> json, {
  required void Function(String nodesPath) onNodeDecoded,
}) {
  final layersJson = sceneBuilderRequireList(json, 'layers');
  sceneRequireContentLayerLimit(layersJson.length);
  final layers = <ContentLayerSnapshot>[];
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

BackgroundLayerSnapshot _decodeBackgroundLayer(
  Map<String, Object?> json, {
  required String layerPath,
  required void Function(String nodesPath) onNodeDecoded,
}) {
  return backgroundLayerSnapshotFromValidated(
    nodes: _decodeLayerNodes(
      json,
      layerPath: layerPath,
      onNodeDecoded: onNodeDecoded,
    ),
  );
}

ContentLayerSnapshot _decodeContentLayer(
  Map<String, Object?> json, {
  required String layerPath,
  required void Function(String nodesPath) onNodeDecoded,
}) {
  return contentLayerSnapshotFromValidated(
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

List<NodeSnapshot> _decodeLayerNodes(
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
  final nodes = <NodeSnapshot>[];
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
