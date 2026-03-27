import 'dart:ui';

import '../contract/internal/node_boundary_schema.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../contract/validated/finite_offset_value.dart';
import '../contract/validated/font_family_value.dart';
import '../contract/validated/image_id_value.dart';
import '../contract/validated/instance_revision_value.dart';
import '../contract/validated/layer_id_value.dart';
import '../contract/validated/node_id_value.dart';
import '../contract/validated/svg_path_data_value.dart';
import '../contract/validated/text_content_value.dart';
import '../contract/validated/validated_value_support.dart';
import '../core/nodes.dart';
import '../core/scene_limits.dart';
import 'scene_builder_json_require.dart';
import 'scene_structural_limits.dart';

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

SceneSnapshot sceneBuilderDecodeSnapshotFromJson(Map<String, Object?> json) {
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
      _decodeNode(
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

NodeSnapshotCommonSchemaFields _decodeNodeCommonFields(
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

ImageNodeSchemaFields _decodeImageFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: ImageIdValue.fromJson(
      sceneBuilderRequireField(json, 'imageId', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'imageId'),
      fieldName: 'imageId',
    ).value,
    size: sceneBuilderRequireSize(json, 'size', pathPrefix: nodePath),
    naturalSize: sceneBuilderOptionalSizeMap(
      json,
      'naturalSize',
      pathPrefix: nodePath,
    ),
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

TextNodeSnapshotSchemaFields _decodeTextFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final textFields = _decodeTextSpecFields(json, nodePath: nodePath);
  return NodeBoundarySchema.textSnapshotFieldsFromValidated((
    text: textFields.text,
    size: sceneBuilderRequireSize(json, 'size', pathPrefix: nodePath),
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

TextNodeSpecSchemaFields _decodeTextSpecFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final flags = _decodeTextFlags(json, nodePath: nodePath);
  final optionals = _decodeTextOptionals(json, nodePath: nodePath);
  return NodeBoundarySchema.textSpecFieldsFromValidated((
    text: _decodeRequiredTextContent(json, nodePath: nodePath),
    fontSize: validatedRequireJsonPositiveFiniteDouble(
      sceneBuilderRequireField(json, 'fontSize', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'fontSize'),
      fieldName: 'fontSize',
    ),
    color: sceneBuilderParseColor(
      sceneBuilderRequireTypedField<String>(
        json,
        'color',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: sceneBuilderPathAt(nodePath, 'color'),
    ),
    align: sceneBuilderParseTextAlign(
      sceneBuilderRequireTypedField<String>(
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
    sceneBuilderRequireTypedField<String>(
      json,
      'text',
      pathPrefix: nodePath,
      typeLabel: 'string',
    ),
    path: sceneBuilderPathAt(nodePath, 'text'),
    fieldName: 'text',
  ).value;
}

({bool isBold, bool isItalic, bool isUnderline}) _decodeTextFlags(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return (
    isBold: sceneBuilderRequireTypedField<bool>(
      json,
      'isBold',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isItalic: sceneBuilderRequireTypedField<bool>(
      json,
      'isItalic',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isUnderline: sceneBuilderRequireTypedField<bool>(
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
    fontFamily: sceneBuilderOptionalValidatedField(
      json,
      'fontFamily',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          FontFamilyValue.fromJson(
            value,
            path: path,
            fieldName: fieldName,
          ).value,
    ),
    maxWidth: sceneBuilderOptionalValidatedField(
      json,
      'maxWidth',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonPositiveFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    lineHeight: sceneBuilderOptionalValidatedField(
      json,
      'lineHeight',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonPositiveFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
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
    thickness: validatedRequireJsonPositiveFiniteDouble(
      sceneBuilderRequireField(json, 'thickness', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'thickness'),
      fieldName: 'thickness',
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
    pointsRevision: fields.pointsRevision,
    thickness: fields.thickness,
    color: fields.color,
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

List<Offset> _decodeStrokePoints(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final pointsPath = sceneBuilderPathAt(nodePath, 'localPoints');
  final pointsJson = sceneBuilderRequireList(
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
      FiniteOffsetValue.fromJson(
        pointsJson[i],
        path: sceneBuilderPathAt(pointsPath, '[$i]'),
        fieldName: sceneBuilderPathAt(pointsPath, '[$i]'),
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
    start: validatedRequireJsonFiniteOffset(
      sceneBuilderRequireField(json, 'localA', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'localA'),
      fieldName: 'localA',
    ),
    end: validatedRequireJsonFiniteOffset(
      sceneBuilderRequireField(json, 'localB', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'localB'),
      fieldName: 'localB',
    ),
    thickness: validatedRequireJsonPositiveFiniteDouble(
      sceneBuilderRequireField(json, 'thickness', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'thickness'),
      fieldName: 'thickness',
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

PathNodeSchemaFields _decodePathFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: SvgPathDataValue.fromJson(
      sceneBuilderRequireTypedField<String>(
        json,
        'svgPathData',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: sceneBuilderPathAt(nodePath, 'svgPathData'),
      fieldName: 'svgPathData',
    ).value,
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
    fillRule: sceneBuilderParsePathFillRule(
      sceneBuilderRequireTypedField<String>(
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

Color _decodeRequiredColor(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  return sceneBuilderParseColor(
    sceneBuilderRequireTypedField<String>(
      json,
      key,
      pathPrefix: pathPrefix,
      typeLabel: 'string',
    ),
    path: sceneBuilderPathAt(pathPrefix, key),
  );
}
