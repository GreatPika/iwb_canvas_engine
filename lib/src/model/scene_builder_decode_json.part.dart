part of 'scene_builder.dart';

SceneSnapshot _decodeSnapshotFromJson(Map<String, Object?> json) {
  final version = _requireInt(json, 'schemaVersion');
  if (version < sceneSchemaVersionMin || version > sceneSchemaVersionMax) {
    throw SceneDataException(
      code: SceneDataErrorCode.unsupportedSchemaVersion,
      path: 'schemaVersion',
      message: 'Unsupported schemaVersion: $version. Expected one of: [4].',
    );
  }

  final cameraJson = _requireMap(json, 'camera');
  final camera = CameraSnapshot(
    offset: Offset(
      _requireDouble(cameraJson, 'offsetX'),
      _requireDouble(cameraJson, 'offsetY'),
    ),
  );

  final backgroundJson = _requireMap(json, 'background');
  final gridJson = _requireMap(backgroundJson, 'grid');
  final background = BackgroundSnapshot(
    color: _parseColor(_requireString(backgroundJson, 'color')),
    grid: GridSnapshot(
      isEnabled: _requireBool(gridJson, 'enabled'),
      cellSize: _requireDouble(gridJson, 'cellSize'),
      color: _parseColor(_requireString(gridJson, 'color')),
    ),
  );

  final paletteJson = _requireMap(json, 'palette');
  final penColorsJson = _requireList(paletteJson, 'penColors');
  final backgroundColorsJson = _requireList(paletteJson, 'backgroundColors');
  final gridSizesJson = _requireList(paletteJson, 'gridSizes');
  final palette = ScenePaletteSnapshot(
    penColors: penColorsJson
        .map((value) => _parseColor(_requireStringValue(value, 'penColors')))
        .toList(growable: false),
    backgroundColors: backgroundColorsJson
        .map(
          (value) =>
              _parseColor(_requireStringValue(value, 'backgroundColors')),
        )
        .toList(growable: false),
    gridSizes: gridSizesJson
        .map((value) => _requireDoubleValue(value, 'gridSizes'))
        .toList(growable: false),
  );

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
    backgroundLayer = _decodeBackgroundLayer(_castMap(backgroundLayerJson));
  }

  final layersJson = _requireList(json, 'layers');
  final layers = layersJson
      .map((layerJson) {
        if (layerJson is! Map) {
          throw SceneDataException(
            code: SceneDataErrorCode.invalidFieldType,
            path: 'layers',
            message: 'Layer must be an object.',
          );
        }
        return _decodeContentLayer(_castMap(layerJson));
      })
      .toList(growable: false);

  return SceneSnapshot(
    backgroundLayer: backgroundLayer,
    layers: layers,
    camera: camera,
    background: background,
    palette: palette,
  );
}

BackgroundLayerSnapshot _decodeBackgroundLayer(Map<String, Object?> json) {
  final nodesJson = _requireList(json, 'nodes');
  final nodes = nodesJson
      .map((nodeJson) {
        if (nodeJson is! Map) {
          throw SceneDataException(
            code: SceneDataErrorCode.invalidFieldType,
            path: 'backgroundLayer.nodes',
            message: 'Node must be an object.',
          );
        }
        return _decodeNode(_castMap(nodeJson));
      })
      .toList(growable: false);
  return BackgroundLayerSnapshot(nodes: nodes);
}

ContentLayerSnapshot _decodeContentLayer(Map<String, Object?> json) {
  final nodesJson = _requireList(json, 'nodes');
  final nodes = nodesJson
      .map((nodeJson) {
        if (nodeJson is! Map) {
          throw SceneDataException(
            code: SceneDataErrorCode.invalidFieldType,
            path: 'layers.nodes',
            message: 'Node must be an object.',
          );
        }
        return _decodeNode(_castMap(nodeJson));
      })
      .toList(growable: false);
  return ContentLayerSnapshot(nodes: nodes);
}

NodeSnapshot _decodeNode(Map<String, Object?> json) {
  final type = _parseNodeType(_requireString(json, 'type'));
  final id = _requireString(json, 'id');
  final instanceRevision = _optionalInt(json, 'instanceRevision') ?? 0;
  final transform = _decodeTransform2D(_requireMap(json, 'transform'));
  final hitPadding = _requireDouble(json, 'hitPadding');
  final opacity = _requireDouble(json, 'opacity');
  final isVisible = _requireBool(json, 'isVisible');
  final isSelectable = _requireBool(json, 'isSelectable');
  final isLocked = _requireBool(json, 'isLocked');
  final isDeletable = _requireBool(json, 'isDeletable');
  final isTransformable = _requireBool(json, 'isTransformable');

  switch (type) {
    case NodeType.image:
      return ImageNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        imageId: _requireString(json, 'imageId'),
        size: _requireSize(json, 'size'),
        naturalSize: _optionalSizeMap(json, 'naturalSize'),
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
        text: _requireString(json, 'text'),
        size: _requireSize(json, 'size'),
        fontSize: _requireDouble(json, 'fontSize'),
        color: _parseColor(_requireString(json, 'color')),
        align: _parseTextAlign(_requireString(json, 'align')),
        isBold: _requireBool(json, 'isBold'),
        isItalic: _requireBool(json, 'isItalic'),
        isUnderline: _requireBool(json, 'isUnderline'),
        fontFamily: _optionalString(json, 'fontFamily'),
        maxWidth: _optionalDouble(json, 'maxWidth'),
        lineHeight: _optionalDouble(json, 'lineHeight'),
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
      return StrokeNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        points: _requireList(json, 'localPoints')
            .map((point) => _parsePoint(point, 'localPoints'))
            .toList(growable: false),
        thickness: _requireDouble(json, 'thickness'),
        color: _parseColor(_requireString(json, 'color')),
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
        start: _parsePoint(_requireMap(json, 'localA'), 'localA'),
        end: _parsePoint(_requireMap(json, 'localB'), 'localB'),
        thickness: _requireDouble(json, 'thickness'),
        color: _parseColor(_requireString(json, 'color')),
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
        size: _requireSize(json, 'size'),
        fillColor: _optionalColor(json, 'fillColor'),
        strokeColor: _optionalColor(json, 'strokeColor'),
        strokeWidth: _requireDouble(json, 'strokeWidth'),
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
      return PathNodeSnapshot(
        id: id,
        instanceRevision: instanceRevision,
        svgPathData: _requireString(json, 'svgPathData'),
        fillColor: _optionalColor(json, 'fillColor'),
        strokeColor: _optionalColor(json, 'strokeColor'),
        strokeWidth: _requireDouble(json, 'strokeWidth'),
        fillRule: _parsePathFillRule(_requireString(json, 'fillRule')),
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
