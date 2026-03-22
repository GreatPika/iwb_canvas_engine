part of 'scene_builder.dart';

typedef _DecodedScenePayload = ({
  CameraSnapshot camera,
  BackgroundSnapshot background,
  ScenePaletteSnapshot palette,
  BackgroundLayerSnapshot? backgroundLayer,
  List<ContentLayerSnapshot> layers,
});

typedef _DecodeNodeSchemaFields<FieldsT> =
    FieldsT Function(Map<String, Object?> json, {required String nodePath});

typedef _NodeSnapshotFieldsBuilder<FieldsT, SnapshotT extends NodeSnapshot> =
    SnapshotT Function(FieldsT fields);

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
  return _requireValidatedField(
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

NodeSnapshot _decodeNode(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final type = _decodeNodeType(json, nodePath: nodePath);
  final common = _decodeNodeCommonFields(json, nodePath: nodePath);
  return switch (type) {
    NodeType.image => _decodeImageSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.text => _decodeTextSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.stroke => _decodeStrokeSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.line => _decodeLineSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.rect => _decodeRectSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
    NodeType.path => _decodePathSnapshot(
      json,
      nodePath: nodePath,
      common: common,
    ),
  };
}

ImageNodeSnapshot _decodeImageSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) => _decodeNodeSnapshotFamily(
  json,
  nodePath: nodePath,
  decodeFields: _decodeImageFields,
  buildSnapshot: (fields) =>
      _imageSnapshotFromSchema(common: common, fields: fields),
);

TextNodeSnapshot _decodeTextSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) => _decodeNodeSnapshotFamily(
  json,
  nodePath: nodePath,
  decodeFields: _decodeTextFields,
  buildSnapshot: (fields) =>
      _textSnapshotFromSchema(common: common, fields: fields),
);

StrokeNodeSnapshot _decodeStrokeSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) => _decodeNodeSnapshotFamily(
  json,
  nodePath: nodePath,
  decodeFields: _decodeStrokeFields,
  buildSnapshot: (fields) =>
      _strokeSnapshotFromSchema(common: common, fields: fields),
);

LineNodeSnapshot _decodeLineSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) => _decodeNodeSnapshotFamily(
  json,
  nodePath: nodePath,
  decodeFields: _decodeLineFields,
  buildSnapshot: (fields) =>
      _lineSnapshotFromSchema(common: common, fields: fields),
);

RectNodeSnapshot _decodeRectSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) => _decodeNodeSnapshotFamily(
  json,
  nodePath: nodePath,
  decodeFields: _decodeRectFields,
  buildSnapshot: (fields) =>
      _rectSnapshotFromSchema(common: common, fields: fields),
);

PathNodeSnapshot _decodePathSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) => _decodeNodeSnapshotFamily(
  json,
  nodePath: nodePath,
  decodeFields: _decodePathFields,
  buildSnapshot: (fields) =>
      _pathSnapshotFromSchema(common: common, fields: fields),
);

SnapshotT _decodeNodeSnapshotFamily<FieldsT, SnapshotT extends NodeSnapshot>(
  Map<String, Object?> json, {
  required String nodePath,
  required _DecodeNodeSchemaFields<FieldsT> decodeFields,
  required _NodeSnapshotFieldsBuilder<FieldsT, SnapshotT> buildSnapshot,
}) {
  return buildSnapshot(decodeFields(json, nodePath: nodePath));
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

NodeSnapshotCommonSchemaFields _decodeNodeCommonFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final flags = _decodeNodeFlags(json, nodePath: nodePath);
  return NodeBoundarySchema.snapshotCommonFromValidated((
    id: _decodeNodeId(json, nodePath: nodePath),
    instanceRevision: _decodeNodeInstanceRevision(json, nodePath: nodePath),
    transform: _decodeNodeTransform(json, nodePath: nodePath),
    hitPadding: _requireNonNegativeFiniteDouble(
      json,
      'hitPadding',
      pathPrefix: nodePath,
    ),
    opacity: _requireOpacity(json, 'opacity', pathPrefix: nodePath),
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
  return _requireValidatedField(
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
  return _optionalValidatedField(
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
  return _decodeTransform2D(
    _requireMap(json, 'transform', pathPrefix: nodePath),
    pathPrefix: _pathAt(nodePath, 'transform'),
  );
}

ImageNodeSchemaFields _decodeImageFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: ImageIdValue.fromJson(
      _requireField(json, 'imageId', pathPrefix: nodePath),
      path: _pathAt(nodePath, 'imageId'),
      fieldName: 'imageId',
    ).value,
    size: _requireSize(json, 'size', pathPrefix: nodePath),
    naturalSize: _optionalSizeMap(json, 'naturalSize', pathPrefix: nodePath),
  ));
}

ImageNodeSnapshot _imageSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required ImageNodeSchemaFields fields,
}) {
  return imageNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
    hitPadding: common.hitPadding,
    transform: common.transform,
    opacity: common.opacity,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

TextNodeSnapshotSchemaFields _decodeTextFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final textFields = _decodeTextSpecFields(json, nodePath: nodePath);
  return NodeBoundarySchema.textSnapshotFieldsFromValidated((
    text: textFields.text,
    size: _requireSize(json, 'size', pathPrefix: nodePath),
    fontSize: textFields.fontSize,
    color: textFields.color,
    align: textFields.align,
    isBold: textFields.isBold,
    isItalic: textFields.isItalic,
    isUnderline: textFields.isUnderline,
    fontFamily: textFields.fontFamily,
    maxWidth: textFields.maxWidth,
    lineHeight: textFields.lineHeight,
  ));
}

TextNodeSnapshot _textSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required TextNodeSnapshotSchemaFields fields,
}) {
  return textNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: fields.size,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    hitPadding: common.hitPadding,
    transform: common.transform,
    opacity: common.opacity,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

TextNodeSpecSchemaFields _decodeTextSpecFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final flags = _decodeTextFlags(json, nodePath: nodePath);
  final optionals = _decodeTextOptionals(json, nodePath: nodePath);
  return NodeBoundarySchema.textSpecFieldsFromValidated((
    text: _decodeRequiredTextContent(json, nodePath: nodePath),
    fontSize: _requirePositiveFiniteDouble(
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
    isBold: flags.isBold,
    isItalic: flags.isItalic,
    isUnderline: flags.isUnderline,
    fontFamily: optionals.fontFamily,
    maxWidth: optionals.maxWidth,
    lineHeight: optionals.lineHeight,
  ));
}

String _decodeRequiredTextContent(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return TextContentValue.fromJson(
    _requireTypedField<String>(
      json,
      'text',
      pathPrefix: nodePath,
      typeLabel: 'string',
    ),
    path: _pathAt(nodePath, 'text'),
    fieldName: 'text',
  ).value;
}

({bool isBold, bool isItalic, bool isUnderline}) _decodeTextFlags(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return (
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
  );
}

({String? fontFamily, double? maxWidth, double? lineHeight})
_decodeTextOptionals(Map<String, Object?> json, {required String nodePath}) {
  return (
    fontFamily: _optionalFontFamily(json, pathPrefix: nodePath),
    maxWidth: _optionalPositiveFiniteDouble(
      json,
      'maxWidth',
      pathPrefix: nodePath,
    ),
    lineHeight: _optionalPositiveFiniteDouble(
      json,
      'lineHeight',
      pathPrefix: nodePath,
    ),
  );
}

StrokeNodeSnapshotSchemaFields _decodeStrokeFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: _decodeStrokePoints(json, nodePath: nodePath),
    pointsRevision: 0,
    thickness: _requirePositiveFiniteDouble(
      json,
      'thickness',
      pathPrefix: nodePath,
    ),
    color: _decodeRequiredColor(json, 'color', pathPrefix: nodePath),
  ));
}

StrokeNodeSnapshot _strokeSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
  return strokeNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
    hitPadding: common.hitPadding,
    transform: common.transform,
    opacity: common.opacity,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
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

LineNodeSchemaFields _decodeLineFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.lineFieldsFromValidated((
    start: _requireFiniteOffset(json, 'localA', pathPrefix: nodePath),
    end: _requireFiniteOffset(json, 'localB', pathPrefix: nodePath),
    thickness: _requirePositiveFiniteDouble(
      json,
      'thickness',
      pathPrefix: nodePath,
    ),
    color: _decodeRequiredColor(json, 'color', pathPrefix: nodePath),
  ));
}

LineNodeSnapshot _lineSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required LineNodeSchemaFields fields,
}) {
  return lineNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
    hitPadding: common.hitPadding,
    transform: common.transform,
    opacity: common.opacity,
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
    size: _requireSize(json, 'size', pathPrefix: nodePath),
    fillColor: _optionalColor(json, 'fillColor', pathPrefix: nodePath),
    strokeColor: _optionalColor(json, 'strokeColor', pathPrefix: nodePath),
    strokeWidth: _requireNonNegativeFiniteDouble(
      json,
      'strokeWidth',
      pathPrefix: nodePath,
    ),
  ));
}

RectNodeSnapshot _rectSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return rectNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    hitPadding: common.hitPadding,
    transform: common.transform,
    opacity: common.opacity,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

PathNodeSchemaFields _decodePathFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.pathFieldsFromValidated((
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
    strokeWidth: _requireNonNegativeFiniteDouble(
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
  ));
}

PathNodeSnapshot _pathSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return pathNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
    hitPadding: common.hitPadding,
    transform: common.transform,
    opacity: common.opacity,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

Color _decodeRequiredColor(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  return _parseColor(
    _requireTypedField<String>(
      json,
      key,
      pathPrefix: pathPrefix,
      typeLabel: 'string',
    ),
    path: _pathAt(pathPrefix, key),
  );
}
