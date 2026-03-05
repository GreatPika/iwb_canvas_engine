part of 'scene_builder.dart';

SceneSnapshot _decodeSnapshotFromJson(Map<String, Object?> json) {
  final version = _requireInt(json, 'schemaVersion');
  if (version < sceneSchemaVersionMin || version > sceneSchemaVersionMax) {
    throw SceneDataException(
      code: SceneDataErrorCode.unsupportedSchemaVersion,
      path: 'schemaVersion',
      message: 'Unsupported schemaVersion: $version. Expected one of: [5].',
    );
  }

  final cameraJson = _requireMap(json, 'camera');
  final camera = CameraSnapshot(
    offset: Offset(
      _requireDouble(cameraJson, 'offsetX', pathPrefix: 'camera'),
      _requireDouble(cameraJson, 'offsetY', pathPrefix: 'camera'),
    ),
  );

  final backgroundJson = _requireMap(json, 'background');
  final gridJson = _requireMap(
    backgroundJson,
    'grid',
    pathPrefix: 'background',
  );
  final background = BackgroundSnapshot(
    color: _parseColor(
      _requireString(backgroundJson, 'color', pathPrefix: 'background'),
      path: 'background.color',
    ),
    grid: GridSnapshot(
      isEnabled: _requireBool(
        gridJson,
        'enabled',
        pathPrefix: 'background.grid',
      ),
      cellSize: _requireDouble(
        gridJson,
        'cellSize',
        pathPrefix: 'background.grid',
      ),
      color: _parseColor(
        _requireString(gridJson, 'color', pathPrefix: 'background.grid'),
        path: 'background.grid.color',
      ),
    ),
  );

  final paletteJson = _requireMap(json, 'palette');
  final penColorsJson = _requireList(
    paletteJson,
    'penColors',
    pathPrefix: 'palette',
    maxLength: kMaxPaletteItems,
  );
  final backgroundColorsJson = _requireList(
    paletteJson,
    'backgroundColors',
    pathPrefix: 'palette',
    maxLength: kMaxPaletteItems,
  );
  final gridSizesJson = _requireList(
    paletteJson,
    'gridSizes',
    pathPrefix: 'palette',
    maxLength: kMaxPaletteItems,
  );

  final penColorsPath = 'palette.penColors';
  final backgroundColorsPath = 'palette.backgroundColors';
  final gridSizesPath = 'palette.gridSizes';

  final penColors = <Color>[];
  for (var i = 0; i < penColorsJson.length; i++) {
    final path = _pathAt(penColorsPath, '[$i]');
    final value = _requireStringValue(
      penColorsJson[i],
      field: 'penColors',
      path: path,
    );
    penColors.add(_parseColor(value, path: path));
  }

  final backgroundColors = <Color>[];
  for (var i = 0; i < backgroundColorsJson.length; i++) {
    final path = _pathAt(backgroundColorsPath, '[$i]');
    final value = _requireStringValue(
      backgroundColorsJson[i],
      field: 'backgroundColors',
      path: path,
    );
    backgroundColors.add(_parseColor(value, path: path));
  }

  final gridSizes = <double>[];
  for (var i = 0; i < gridSizesJson.length; i++) {
    final path = _pathAt(gridSizesPath, '[$i]');
    gridSizes.add(
      _requireDoubleValue(gridSizesJson[i], field: 'gridSizes', path: path),
    );
  }

  final palette = ScenePaletteSnapshot(
    penColors: penColors,
    backgroundColors: backgroundColors,
    gridSizes: gridSizes,
  );

  var totalNodeCount = 0;
  void countNode(String nodesPath) {
    totalNodeCount = _consumeSceneNodeBudget(
      totalNodeCount: totalNodeCount,
      path: nodesPath,
    );
  }

  BackgroundLayerSnapshot? backgroundLayer;
  final backgroundLayerJson = json['backgroundLayer'];
  if (backgroundLayerJson != null) {
    if (backgroundLayerJson is! Map) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidFieldType,
        path: 'backgroundLayer',
        message: 'Layer must be an object.',
      );
    }
    backgroundLayer = _decodeBackgroundLayer(
      _castMap(backgroundLayerJson, path: 'backgroundLayer'),
      layerPath: 'backgroundLayer',
      onNodeDecoded: countNode,
    );
  }

  final layersJson = _requireList(json, 'layers');
  if (layersJson.length > kMaxContentLayersPerScene) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: 'layers',
      message:
          'Field layers must contain at most $kMaxContentLayersPerScene items.',
      source: layersJson.length,
    );
  }

  final layers = <ContentLayerSnapshot>[];
  for (var layerIndex = 0; layerIndex < layersJson.length; layerIndex++) {
    final layerPath = 'layers[$layerIndex]';
    final layerJson = layersJson[layerIndex];
    if (layerJson is! Map) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidFieldType,
        path: layerPath,
        message: 'Layer must be an object.',
      );
    }
    final layer = _decodeContentLayer(
      _castMap(layerJson, path: layerPath),
      layerPath: layerPath,
      onNodeDecoded: countNode,
    );
    layers.add(layer);
  }

  return SceneSnapshot(
    backgroundLayer: backgroundLayer,
    layers: layers,
    camera: camera,
    background: background,
    palette: palette,
  );
}

BackgroundLayerSnapshot _decodeBackgroundLayer(
  Map<String, Object?> json, {
  required String layerPath,
  required void Function(String nodesPath) onNodeDecoded,
}) {
  final nodesJson = _requireList(json, 'nodes', pathPrefix: layerPath);
  final nodesPath = _pathAt(layerPath, 'nodes');
  final nodes = <NodeSnapshot>[];
  for (var nodeIndex = 0; nodeIndex < nodesJson.length; nodeIndex++) {
    onNodeDecoded(nodesPath);
    final nodePath = _pathAt(nodesPath, '[$nodeIndex]');
    final nodeJson = nodesJson[nodeIndex];
    if (nodeJson is! Map) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidFieldType,
        path: nodePath,
        message: 'Node must be an object.',
      );
    }
    nodes.add(
      _decodeNode(_castMap(nodeJson, path: nodePath), nodePath: nodePath),
    );
  }
  return BackgroundLayerSnapshot(nodes: nodes);
}

ContentLayerSnapshot _decodeContentLayer(
  Map<String, Object?> json, {
  required String layerPath,
  required void Function(String nodesPath) onNodeDecoded,
}) {
  final idRaw = json['id'];
  if (idRaw == null) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: '$layerPath.id',
      message: 'Field $layerPath.id must be a string.',
    );
  }
  if (idRaw is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: '$layerPath.id',
      message: 'Field $layerPath.id must be a string.',
      source: idRaw,
    );
  }
  if (idRaw.length > kMaxLayerIdLength) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: '$layerPath.id',
      message:
          'Field $layerPath.id length must be <= $kMaxLayerIdLength characters.',
      source: idRaw.length,
    );
  }
  final id = idRaw;

  final nodesJson = _requireList(json, 'nodes', pathPrefix: layerPath);
  final nodesPath = _pathAt(layerPath, 'nodes');
  final nodes = <NodeSnapshot>[];
  for (var nodeIndex = 0; nodeIndex < nodesJson.length; nodeIndex++) {
    onNodeDecoded(nodesPath);
    final nodePath = _pathAt(nodesPath, '[$nodeIndex]');
    final nodeJson = nodesJson[nodeIndex];
    if (nodeJson is! Map) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidFieldType,
        path: nodePath,
        message: 'Node must be an object.',
      );
    }
    nodes.add(
      _decodeNode(_castMap(nodeJson, path: nodePath), nodePath: nodePath),
    );
  }
  return ContentLayerSnapshot(id: id, nodes: nodes);
}

int _consumeSceneNodeBudget({
  required int totalNodeCount,
  required String path,
}) {
  final nextTotalNodeCount = totalNodeCount + 1;
  if (nextTotalNodeCount <= kMaxNodesPerScene) {
    return nextTotalNodeCount;
  }
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: path,
    message: 'Scene must contain at most $kMaxNodesPerScene nodes.',
    source: nextTotalNodeCount,
  );
}

NodeSnapshot _decodeNode(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final type = _parseNodeType(
    _requireString(json, 'type', pathPrefix: nodePath),
    pathPrefix: nodePath,
  );
  final id = _requireString(
    json,
    'id',
    pathPrefix: nodePath,
    maxLength: kMaxNodeIdLength,
  );
  final instanceRevision =
      _optionalInt(json, 'instanceRevision', pathPrefix: nodePath) ?? 0;
  final transform = _decodeTransform2D(
    _requireMap(json, 'transform', pathPrefix: nodePath),
    pathPrefix: _pathAt(nodePath, 'transform'),
  );
  final hitPadding = _requireDouble(json, 'hitPadding', pathPrefix: nodePath);
  final opacity = _requireDouble(json, 'opacity', pathPrefix: nodePath);
  final isVisible = _requireBool(json, 'isVisible', pathPrefix: nodePath);
  final isSelectable = _requireBool(json, 'isSelectable', pathPrefix: nodePath);
  final isLocked = _requireBool(json, 'isLocked', pathPrefix: nodePath);
  final isDeletable = _requireBool(json, 'isDeletable', pathPrefix: nodePath);
  final isTransformable = _requireBool(
    json,
    'isTransformable',
    pathPrefix: nodePath,
  );

  switch (type) {
    case NodeType.image:
      return ImageNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        imageId: _requireString(
          json,
          'imageId',
          pathPrefix: nodePath,
          maxLength: kMaxImageIdLength,
        ),
        size: _requireSize(json, 'size', pathPrefix: nodePath),
        naturalSize: _optionalSizeMap(
          json,
          'naturalSize',
          pathPrefix: nodePath,
        ),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
    case NodeType.text:
      return TextNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        text: _requireString(
          json,
          'text',
          pathPrefix: nodePath,
          maxLength: kMaxTextLength,
        ),
        size: _requireSize(json, 'size', pathPrefix: nodePath),
        fontSize: _requireDouble(json, 'fontSize', pathPrefix: nodePath),
        color: _parseColor(
          _requireString(json, 'color', pathPrefix: nodePath),
          path: _pathAt(nodePath, 'color'),
        ),
        align: _parseTextAlign(
          _requireString(json, 'align', pathPrefix: nodePath),
          pathPrefix: nodePath,
        ),
        isBold: _requireBool(json, 'isBold', pathPrefix: nodePath),
        isItalic: _requireBool(json, 'isItalic', pathPrefix: nodePath),
        isUnderline: _requireBool(json, 'isUnderline', pathPrefix: nodePath),
        fontFamily: _optionalString(
          json,
          'fontFamily',
          pathPrefix: nodePath,
          maxLength: kMaxFontFamilyLength,
        ),
        maxWidth: _optionalDouble(json, 'maxWidth', pathPrefix: nodePath),
        lineHeight: _optionalDouble(json, 'lineHeight', pathPrefix: nodePath),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
    case NodeType.stroke:
      final pointsPath = _pathAt(nodePath, 'localPoints');
      final pointsJson = _requireList(
        json,
        'localPoints',
        pathPrefix: nodePath,
      );
      if (pointsJson.length > kMaxStrokePointsPerNode) {
        throw SceneDataException(
          code: SceneDataErrorCode.invalidValue,
          path: pointsPath,
          message:
              'Field localPoints must contain at most $kMaxStrokePointsPerNode points.',
          source: pointsJson.length,
        );
      }
      final points = <Offset>[];
      for (var i = 0; i < pointsJson.length; i++) {
        points.add(
          _parsePoint(pointsJson[i], pathPrefix: _pathAt(pointsPath, '[$i]')),
        );
      }
      return StrokeNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        points: points,
        thickness: _requireDouble(json, 'thickness', pathPrefix: nodePath),
        color: _parseColor(
          _requireString(json, 'color', pathPrefix: nodePath),
          path: _pathAt(nodePath, 'color'),
        ),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
    case NodeType.line:
      return LineNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        start: _parsePoint(
          _requireMap(json, 'localA', pathPrefix: nodePath),
          pathPrefix: _pathAt(nodePath, 'localA'),
        ),
        end: _parsePoint(
          _requireMap(json, 'localB', pathPrefix: nodePath),
          pathPrefix: _pathAt(nodePath, 'localB'),
        ),
        thickness: _requireDouble(json, 'thickness', pathPrefix: nodePath),
        color: _parseColor(
          _requireString(json, 'color', pathPrefix: nodePath),
          path: _pathAt(nodePath, 'color'),
        ),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
    case NodeType.rect:
      return RectNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        size: _requireSize(json, 'size', pathPrefix: nodePath),
        fillColor: _optionalColor(json, 'fillColor', pathPrefix: nodePath),
        strokeColor: _optionalColor(json, 'strokeColor', pathPrefix: nodePath),
        strokeWidth: _requireDouble(json, 'strokeWidth', pathPrefix: nodePath),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
    case NodeType.path:
      final svgPathData = _requireString(
        json,
        'svgPathData',
        pathPrefix: nodePath,
      );
      if (svgPathData.length > kMaxSvgPathDataLength) {
        throw SceneDataException(
          code: SceneDataErrorCode.invalidValue,
          path: _pathAt(nodePath, 'svgPathData'),
          message:
              'Field svgPathData length must be <= $kMaxSvgPathDataLength characters.',
          source: svgPathData.length,
        );
      }
      return PathNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        svgPathData: svgPathData,
        fillColor: _optionalColor(json, 'fillColor', pathPrefix: nodePath),
        strokeColor: _optionalColor(json, 'strokeColor', pathPrefix: nodePath),
        strokeWidth: _requireDouble(json, 'strokeWidth', pathPrefix: nodePath),
        fillRule: _parsePathFillRule(
          _requireString(json, 'fillRule', pathPrefix: nodePath),
          pathPrefix: nodePath,
        ),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
  }
}
