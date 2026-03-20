part of 'scene_builder.dart';

typedef _DecodedScenePayload = ({
  CameraSnapshot camera,
  BackgroundSnapshot background,
  ScenePaletteSnapshot palette,
  BackgroundLayerSnapshot? backgroundLayer,
  List<ContentLayerSnapshot> layers,
});

typedef _DecodedNodeBaseFields = ({
  String id,
  int instanceRevision,
  Transform2D transform,
  double hitPadding,
  double opacity,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef _DecodedTextFields = ({
  String text,
  Size size,
  double fontSize,
  Color color,
  TextAlign align,
  bool isBold,
  bool isItalic,
  bool isUnderline,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
});

SceneSnapshot _decodeSnapshotFromJson(Map<String, Object?> json) {
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
  final version = _requireInt(json, 'schemaVersion');
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

_DecodedScenePayload _decodeScenePayload(Map<String, Object?> json) {
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
  final cameraJson = _requireMap(json, 'camera');
  return cameraSnapshotFromValidated(
    offset: Offset(
      _requireDouble(cameraJson, 'offsetX', pathPrefix: 'camera'),
      _requireDouble(cameraJson, 'offsetY', pathPrefix: 'camera'),
    ),
  );
}

BackgroundSnapshot _decodeBackgroundSnapshot(Map<String, Object?> json) {
  final backgroundJson = _requireMap(json, 'background');
  final gridJson = _requireMap(
    backgroundJson,
    'grid',
    pathPrefix: 'background',
  );
  return backgroundSnapshotFromValidated(
    color: _parseColor(
      _requireTypedField<String>(
        backgroundJson,
        'color',
        pathPrefix: 'background',
        typeLabel: 'string',
      ),
      path: 'background.color',
    ),
    grid: gridSnapshotFromValidated(
      isEnabled: _requireTypedField<bool>(
        gridJson,
        'enabled',
        pathPrefix: 'background.grid',
        typeLabel: 'bool',
      ),
      cellSize: _requireDouble(
        gridJson,
        'cellSize',
        pathPrefix: 'background.grid',
      ),
      color: _parseColor(
        _requireTypedField<String>(
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
  final paletteJson = _requireMap(json, 'palette');
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
  final colorsJson = _requireList(
    paletteJson,
    key,
    pathPrefix: pathPrefix,
    maxLength: kMaxPaletteItems,
  );
  final colorsPath = _pathAt(pathPrefix, key);
  final colors = <Color>[];
  for (var i = 0; i < colorsJson.length; i++) {
    final path = _pathAt(colorsPath, '[$i]');
    final value = _requireStringValue(colorsJson[i], field: key, path: path);
    colors.add(_parseColor(value, path: path));
  }
  return colors;
}

List<double> _decodePaletteGridSizes(Map<String, Object?> paletteJson) {
  final gridSizesJson = _requireList(
    paletteJson,
    'gridSizes',
    pathPrefix: 'palette',
    maxLength: kMaxPaletteItems,
  );
  const gridSizesField = 'gridSizes';
  const gridSizesPath = 'palette.gridSizes';
  final gridSizes = <double>[];
  for (var i = 0; i < gridSizesJson.length; i++) {
    final path = _pathAt(gridSizesPath, '[$i]');
    gridSizes.add(
      _requireDoubleValue(gridSizesJson[i], field: gridSizesField, path: path),
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
    _requireObjectValue(
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
  final layersJson = _requireList(json, 'layers');
  sceneRequireContentLayerLimit(layersJson.length);
  final layers = <ContentLayerSnapshot>[];
  for (var layerIndex = 0; layerIndex < layersJson.length; layerIndex++) {
    final layerPath = 'layers[$layerIndex]';
    layers.add(
      _decodeContentLayer(
        _requireObjectValue(
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
  final idPath = _pathAt(layerPath, 'id');
  if (!json.containsKey('id')) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: idPath,
      message: 'Missing required field $idPath.',
    );
  }
  return LayerIdValue.fromJson(
    json['id'],
    path: idPath,
    fieldName: idPath,
  ).value;
}

List<NodeSnapshot> _decodeLayerNodes(
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
    nodes.add(
      _decodeNode(
        _requireObjectValue(
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

Map<String, Object?> _requireObjectValue(
  Object? value, {
  required String path,
  required String objectName,
}) {
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: '$objectName must be an object.',
    );
  }
  return _castMap(value, path: path);
}

NodeSnapshot _decodeNode(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final type = _decodeNodeType(json, nodePath: nodePath);
  final base = _decodeNodeBaseFields(json, nodePath: nodePath);
  switch (type) {
    case NodeType.image:
      return _decodeImageNode(json, nodePath: nodePath, base: base);
    case NodeType.text:
      return _decodeTextNode(json, nodePath: nodePath, base: base);
    case NodeType.stroke:
      return _decodeStrokeNode(json, nodePath: nodePath, base: base);
    case NodeType.line:
      return _decodeLineNode(json, nodePath: nodePath, base: base);
    case NodeType.rect:
      return _decodeRectNode(json, nodePath: nodePath, base: base);
    case NodeType.path:
      return _decodePathNode(json, nodePath: nodePath, base: base);
  }
}

NodeType _decodeNodeType(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return _parseNodeType(
    _requireTypedField<String>(
      json,
      'type',
      pathPrefix: nodePath,
      typeLabel: 'string',
    ),
    pathPrefix: nodePath,
  );
}

_DecodedNodeBaseFields _decodeNodeBaseFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return (
    id: _decodeNodeId(json, nodePath: nodePath),
    instanceRevision: _decodeNodeInstanceRevision(json, nodePath: nodePath),
    transform: _decodeNodeTransform(json, nodePath: nodePath),
    hitPadding: _decodeRequiredNonNegativeFiniteDouble(
      json,
      'hitPadding',
      pathPrefix: nodePath,
    ),
    opacity: _decodeRequiredOpacity(json, 'opacity', pathPrefix: nodePath),
    isVisible: _requireTypedField<bool>(
      json,
      'isVisible',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isSelectable: _requireTypedField<bool>(
      json,
      'isSelectable',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isLocked: _requireTypedField<bool>(
      json,
      'isLocked',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isDeletable: _requireTypedField<bool>(
      json,
      'isDeletable',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isTransformable: _requireTypedField<bool>(
      json,
      'isTransformable',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
  );
}

String _decodeNodeId(Map<String, Object?> json, {required String nodePath}) {
  final idPath = _pathAt(nodePath, 'id');
  if (!json.containsKey('id')) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: idPath,
      message: 'Missing required field $idPath.',
    );
  }
  return NodeIdValue.fromJson(json['id'], path: idPath, fieldName: 'id').value;
}

int _decodeNodeInstanceRevision(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  if (!json.containsKey('instanceRevision') ||
      json['instanceRevision'] == null) {
    return 0;
  }
  return InstanceRevisionValue.fromJson(
    json['instanceRevision'],
    path: _pathAt(nodePath, 'instanceRevision'),
    fieldName: 'instanceRevision',
    allowZero: true,
  ).value;
}

Transform2D _decodeNodeTransform(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return _decodeTransform2D(
    _requireMap(json, 'transform', pathPrefix: nodePath),
    pathPrefix: _pathAt(nodePath, 'transform'),
  );
}

ImageNodeSnapshot _decodeImageNode(
  Map<String, Object?> json, {
  required String nodePath,
  required _DecodedNodeBaseFields base,
}) {
  return imageNodeSnapshotFromValidated(
    id: base.id,
    instanceRevision: base.instanceRevision,
    imageId: ImageIdValue.fromJson(
      _requireField(json, 'imageId', pathPrefix: nodePath),
      path: _pathAt(nodePath, 'imageId'),
      fieldName: 'imageId',
    ).value,
    size: _requireSize(json, 'size', pathPrefix: nodePath),
    naturalSize: _optionalSizeMap(json, 'naturalSize', pathPrefix: nodePath),
    hitPadding: base.hitPadding,
    transform: base.transform,
    opacity: base.opacity,
    isVisible: base.isVisible,
    isSelectable: base.isSelectable,
    isLocked: base.isLocked,
    isDeletable: base.isDeletable,
    isTransformable: base.isTransformable,
  );
}

TextNodeSnapshot _decodeTextNode(
  Map<String, Object?> json, {
  required String nodePath,
  required _DecodedNodeBaseFields base,
}) {
  final textFields = _decodeTextFields(json, nodePath: nodePath);
  return textNodeSnapshotFromValidated(
    id: base.id,
    instanceRevision: base.instanceRevision,
    text: textFields.text,
    size: textFields.size,
    fontSize: textFields.fontSize,
    color: textFields.color,
    align: textFields.align,
    isBold: textFields.isBold,
    isItalic: textFields.isItalic,
    isUnderline: textFields.isUnderline,
    fontFamily: textFields.fontFamily,
    maxWidth: textFields.maxWidth,
    lineHeight: textFields.lineHeight,
    hitPadding: base.hitPadding,
    transform: base.transform,
    opacity: base.opacity,
    isVisible: base.isVisible,
    isSelectable: base.isSelectable,
    isLocked: base.isLocked,
    isDeletable: base.isDeletable,
    isTransformable: base.isTransformable,
  );
}

_DecodedTextFields _decodeTextFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return (
    text: TextContentValue.fromJson(
      _requireTypedField<String>(
        json,
        'text',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: _pathAt(nodePath, 'text'),
      fieldName: 'text',
    ).value,
    size: _requireSize(json, 'size', pathPrefix: nodePath),
    fontSize: _decodeRequiredPositiveFiniteDouble(
      json,
      'fontSize',
      pathPrefix: nodePath,
    ),
    color: _parseColor(
      _requireTypedField<String>(
        json,
        'color',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: _pathAt(nodePath, 'color'),
    ),
    align: _parseTextAlign(
      _requireTypedField<String>(
        json,
        'align',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      pathPrefix: nodePath,
    ),
    isBold: _requireTypedField<bool>(
      json,
      'isBold',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isItalic: _requireTypedField<bool>(
      json,
      'isItalic',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isUnderline: _requireTypedField<bool>(
      json,
      'isUnderline',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    fontFamily: _decodeOptionalFontFamily(json, pathPrefix: nodePath),
    maxWidth: _decodeOptionalPositiveFiniteDouble(
      json,
      'maxWidth',
      pathPrefix: nodePath,
    ),
    lineHeight: _decodeOptionalPositiveFiniteDouble(
      json,
      'lineHeight',
      pathPrefix: nodePath,
    ),
  );
}

StrokeNodeSnapshot _decodeStrokeNode(
  Map<String, Object?> json, {
  required String nodePath,
  required _DecodedNodeBaseFields base,
}) {
  return strokeNodeSnapshotFromValidated(
    id: base.id,
    instanceRevision: base.instanceRevision,
    points: _decodeStrokePoints(json, nodePath: nodePath),
    thickness: _decodeRequiredPositiveFiniteDouble(
      json,
      'thickness',
      pathPrefix: nodePath,
    ),
    color: _parseColor(
      _requireTypedField<String>(
        json,
        'color',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: _pathAt(nodePath, 'color'),
    ),
    hitPadding: base.hitPadding,
    transform: base.transform,
    opacity: base.opacity,
    isVisible: base.isVisible,
    isSelectable: base.isSelectable,
    isLocked: base.isLocked,
    isDeletable: base.isDeletable,
    isTransformable: base.isTransformable,
  );
}

List<Offset> _decodeStrokePoints(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final pointsPath = _pathAt(nodePath, 'localPoints');
  final pointsJson = _requireList(json, 'localPoints', pathPrefix: nodePath);
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
      FiniteOffsetValue.fromJson(
        pointsJson[i],
        path: _pathAt(pointsPath, '[$i]'),
        fieldName: _pathAt(pointsPath, '[$i]'),
      ).value,
    );
  }
  return points;
}

LineNodeSnapshot _decodeLineNode(
  Map<String, Object?> json, {
  required String nodePath,
  required _DecodedNodeBaseFields base,
}) {
  return lineNodeSnapshotFromValidated(
    id: base.id,
    instanceRevision: base.instanceRevision,
    start: _decodeRequiredFiniteOffset(json, 'localA', pathPrefix: nodePath),
    end: _decodeRequiredFiniteOffset(json, 'localB', pathPrefix: nodePath),
    thickness: _decodeRequiredPositiveFiniteDouble(
      json,
      'thickness',
      pathPrefix: nodePath,
    ),
    color: _parseColor(
      _requireTypedField<String>(
        json,
        'color',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: _pathAt(nodePath, 'color'),
    ),
    hitPadding: base.hitPadding,
    transform: base.transform,
    opacity: base.opacity,
    isVisible: base.isVisible,
    isSelectable: base.isSelectable,
    isLocked: base.isLocked,
    isDeletable: base.isDeletable,
    isTransformable: base.isTransformable,
  );
}

RectNodeSnapshot _decodeRectNode(
  Map<String, Object?> json, {
  required String nodePath,
  required _DecodedNodeBaseFields base,
}) {
  return rectNodeSnapshotFromValidated(
    id: base.id,
    instanceRevision: base.instanceRevision,
    size: _requireSize(json, 'size', pathPrefix: nodePath),
    fillColor: _optionalColor(json, 'fillColor', pathPrefix: nodePath),
    strokeColor: _optionalColor(json, 'strokeColor', pathPrefix: nodePath),
    strokeWidth: _decodeRequiredNonNegativeFiniteDouble(
      json,
      'strokeWidth',
      pathPrefix: nodePath,
    ),
    hitPadding: base.hitPadding,
    transform: base.transform,
    opacity: base.opacity,
    isVisible: base.isVisible,
    isSelectable: base.isSelectable,
    isLocked: base.isLocked,
    isDeletable: base.isDeletable,
    isTransformable: base.isTransformable,
  );
}

PathNodeSnapshot _decodePathNode(
  Map<String, Object?> json, {
  required String nodePath,
  required _DecodedNodeBaseFields base,
}) {
  return pathNodeSnapshotFromValidated(
    id: base.id,
    instanceRevision: base.instanceRevision,
    svgPathData: SvgPathDataValue.fromJson(
      _requireTypedField<String>(
        json,
        'svgPathData',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: _pathAt(nodePath, 'svgPathData'),
      fieldName: 'svgPathData',
    ).value,
    fillColor: _optionalColor(json, 'fillColor', pathPrefix: nodePath),
    strokeColor: _optionalColor(json, 'strokeColor', pathPrefix: nodePath),
    strokeWidth: _decodeRequiredNonNegativeFiniteDouble(
      json,
      'strokeWidth',
      pathPrefix: nodePath,
    ),
    fillRule: _parsePathFillRule(
      _requireTypedField<String>(
        json,
        'fillRule',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      pathPrefix: nodePath,
    ),
    hitPadding: base.hitPadding,
    transform: base.transform,
    opacity: base.opacity,
    isVisible: base.isVisible,
    isSelectable: base.isSelectable,
    isLocked: base.isLocked,
    isDeletable: base.isDeletable,
    isTransformable: base.isTransformable,
  );
}

String? _decodeOptionalFontFamily(
  Map<String, Object?> json, {
  required String pathPrefix,
}) {
  if (!json.containsKey('fontFamily')) {
    return null;
  }
  final value = json['fontFamily'];
  if (value == null) {
    return null;
  }
  final path = _pathAt(pathPrefix, 'fontFamily');
  return FontFamilyValue.fromJson(
    value,
    path: path,
    fieldName: 'fontFamily',
  ).value;
}

double _decodeRequiredNonNegativeFiniteDouble(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  final path = _pathAt(pathPrefix, key);
  return NonNegativeFiniteDoubleValue.fromJson(
    _requireField(json, key, pathPrefix: pathPrefix),
    path: path,
    fieldName: key,
  ).value;
}

double _decodeRequiredPositiveFiniteDouble(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  final path = _pathAt(pathPrefix, key);
  return PositiveFiniteDoubleValue.fromJson(
    _requireField(json, key, pathPrefix: pathPrefix),
    path: path,
    fieldName: key,
  ).value;
}

double? _decodeOptionalPositiveFiniteDouble(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final value = json[key];
  if (value == null) {
    return null;
  }
  final path = _pathAt(pathPrefix, key);
  return PositiveFiniteDoubleValue.fromJson(
    value,
    path: path,
    fieldName: key,
  ).value;
}

double _decodeRequiredOpacity(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  final path = _pathAt(pathPrefix, key);
  return OpacityValue.fromJson(
    _requireField(json, key, pathPrefix: pathPrefix),
    path: path,
    fieldName: key,
  ).value;
}

Offset _decodeRequiredFiniteOffset(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  final path = _pathAt(pathPrefix, key);
  return FiniteOffsetValue.fromJson(
    _requireField(json, key, pathPrefix: pathPrefix),
    path: path,
    fieldName: path,
  ).value;
}
