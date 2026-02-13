import 'dart:convert';
import 'dart:ui';

import '../core/background_layer_invariants.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/text_layout.dart';
import '../core/transform2d.dart';
import '../model/document.dart';
import '../model/scene_value_validation.dart';
import '../public/snapshot.dart' hide NodeId;

/// Thrown when scene JSON fails schema validation.
class SceneJsonFormatException implements FormatException {
  SceneJsonFormatException(this.message, [this.source]);

  @override
  final String message;

  @override
  final Object? source;

  @override
  int? get offset => null;

  @override
  String toString() => 'SceneJsonFormatException: $message';
}

/// JSON schema version written by this package.
const int schemaVersionWrite = 2;

/// JSON schema versions accepted by this package.
const Set<int> schemaVersionsRead = {2};

/// Encodes [snapshot] to a JSON string.
String encodeSceneToJson(SceneSnapshot snapshot) {
  return jsonEncode(encodeScene(snapshot));
}

/// Decodes a [SceneSnapshot] from a JSON string.
///
/// Only `schemaVersion = 2` is accepted.
///
/// Throws [SceneJsonFormatException] when the JSON is invalid, the schema
/// version is unsupported, or validation fails.
SceneSnapshot decodeSceneFromJson(String json) {
  try {
    final raw = jsonDecode(json);
    if (raw is! Map<String, dynamic>) {
      throw SceneJsonFormatException('Root JSON must be an object.');
    }
    return decodeScene(raw);
  } on SceneJsonFormatException {
    rethrow;
  } on FormatException catch (error) {
    throw SceneJsonFormatException(error.message, error.source);
  }
}

/// Encodes [snapshot] into a JSON-serializable map.
Map<String, dynamic> encodeScene(SceneSnapshot snapshot) {
  sceneValidateSnapshotValues(
    snapshot,
    onError: _sceneJsonValidationError,
    requirePositiveGridCellSize: true,
  );
  return _encodeSnapshot(snapshot);
}

/// Decodes a [SceneSnapshot] from a JSON map (already parsed).
///
/// Only `schemaVersion = 2` is accepted.
///
/// Throws [SceneJsonFormatException] when validation fails.
SceneSnapshot decodeScene(Map<String, dynamic> json) {
  final sceneDoc = decodeSceneDocument(json);
  return txnSceneToSnapshot(sceneDoc);
}

/// Encodes internal mutable [Scene] document into a JSON-serializable map.
Map<String, dynamic> encodeSceneDocument(Scene scene) {
  sceneValidateSceneValues(
    scene,
    onError: _sceneJsonValidationError,
    requirePositiveGridCellSize: true,
  );
  return <String, dynamic>{
    'schemaVersion': schemaVersionWrite,
    'camera': {
      'offsetX': scene.camera.offset.dx,
      'offsetY': scene.camera.offset.dy,
    },
    'background': {
      'color': _colorToHex(scene.background.color),
      'grid': {
        'enabled': scene.background.grid.isEnabled,
        'cellSize': scene.background.grid.cellSize,
        'color': _colorToHex(scene.background.grid.color),
      },
    },
    'palette': {
      'penColors': scene.palette.penColors.map(_colorToHex).toList(),
      'backgroundColors': scene.palette.backgroundColors
          .map(_colorToHex)
          .toList(),
      'gridSizes': scene.palette.gridSizes,
    },
    'layers': scene.layers.map(_encodeLayer).toList(),
  };
}

/// Decodes internal mutable [Scene] document from a JSON map (already parsed).
///
/// Only `schemaVersion = 2` is accepted.
///
/// Throws [SceneJsonFormatException] when validation fails.
Scene decodeSceneDocument(Map<String, dynamic> json) {
  final version = _requireInt(json, 'schemaVersion');
  if (!schemaVersionsRead.contains(version)) {
    throw SceneJsonFormatException(
      'Unsupported schemaVersion: $version. Expected one of: '
      '${schemaVersionsRead.toList()}.',
    );
  }

  final cameraJson = _requireMap(json, 'camera');
  final camera = Camera(
    offset: Offset(
      _requireDouble(cameraJson, 'offsetX'),
      _requireDouble(cameraJson, 'offsetY'),
    ),
  );

  final backgroundJson = _requireMap(json, 'background');
  final gridJson = _requireMap(backgroundJson, 'grid');
  final gridEnabled = _requireBool(gridJson, 'enabled');
  final background = Background(
    color: _parseColor(_requireString(backgroundJson, 'color')),
    grid: GridSettings(
      isEnabled: gridEnabled,
      cellSize: _requireGridCellSize(gridJson),
      color: _parseColor(_requireString(gridJson, 'color')),
    ),
  );

  final paletteJson = _requireMap(json, 'palette');
  final penColorsJson = _requireList(paletteJson, 'penColors');
  _ensureListNotEmpty(penColorsJson, 'penColors');
  final backgroundColorsJson = _requireList(paletteJson, 'backgroundColors');
  _ensureListNotEmpty(backgroundColorsJson, 'backgroundColors');
  final gridSizesJson = _requireList(paletteJson, 'gridSizes');
  _ensureListNotEmpty(gridSizesJson, 'gridSizes');
  final palette = ScenePalette(
    penColors: penColorsJson
        .map((value) => _parseColor(_requireStringValue(value, 'penColors')))
        .toList(),
    backgroundColors: backgroundColorsJson
        .map(
          (value) =>
              _parseColor(_requireStringValue(value, 'backgroundColors')),
        )
        .toList(),
    gridSizes: gridSizesJson
        .map((value) => _requirePositiveDoubleValue(value, 'gridSizes'))
        .toList(),
  );

  final layersJson = _requireList(json, 'layers');
  final layers = layersJson.map((layerJson) {
    if (layerJson is! Map<String, dynamic>) {
      throw SceneJsonFormatException('Layer must be an object.');
    }
    return _decodeLayer(layerJson);
  }).toList();
  _ensureUniqueNodeIds(layers);
  canonicalizeBackgroundLayerInvariants(
    layers,
    onMultipleBackgroundError: (_) {
      throw SceneJsonFormatException(
        'Scene must contain at most one background layer.',
      );
    },
  );
  final scene = Scene(
    layers: layers,
    camera: camera,
    background: background,
    palette: palette,
  );
  sceneValidateSceneValues(
    scene,
    onError: _sceneJsonValidationError,
    requirePositiveGridCellSize: true,
  );
  return scene;
}

Map<String, dynamic> _encodeSnapshot(SceneSnapshot snapshot) {
  return <String, dynamic>{
    'schemaVersion': schemaVersionWrite,
    'camera': {
      'offsetX': snapshot.camera.offset.dx,
      'offsetY': snapshot.camera.offset.dy,
    },
    'background': {
      'color': _colorToHex(snapshot.background.color),
      'grid': {
        'enabled': snapshot.background.grid.isEnabled,
        'cellSize': snapshot.background.grid.cellSize,
        'color': _colorToHex(snapshot.background.grid.color),
      },
    },
    'palette': {
      'penColors': snapshot.palette.penColors.map(_colorToHex).toList(),
      'backgroundColors': snapshot.palette.backgroundColors
          .map(_colorToHex)
          .toList(),
      'gridSizes': snapshot.palette.gridSizes,
    },
    'layers': snapshot.layers
        .map(
          (layer) => <String, dynamic>{
            'isBackground': layer.isBackground,
            'nodes': layer.nodes
                .map((node) => _encodeNode(txnNodeFromSnapshot(node)))
                .toList(),
          },
        )
        .toList(),
  };
}

Map<String, dynamic> _encodeLayer(Layer layer) {
  return <String, dynamic>{
    'isBackground': layer.isBackground,
    'nodes': layer.nodes.map(_encodeNode).toList(),
  };
}

Layer _decodeLayer(Map<String, dynamic> json) {
  final nodesJson = _requireList(json, 'nodes');
  final nodes = nodesJson.map((nodeJson) {
    if (nodeJson is! Map<String, dynamic>) {
      throw SceneJsonFormatException('Node must be an object.');
    }
    return _decodeNode(nodeJson);
  }).toList();
  return Layer(nodes: nodes, isBackground: _requireBool(json, 'isBackground'));
}

void _ensureUniqueNodeIds(List<Layer> layers) {
  final seen = <NodeId>{};
  for (final layer in layers) {
    for (final node in layer.nodes) {
      if (!seen.add(node.id)) {
        throw SceneJsonFormatException(
          'Duplicate node id: ${node.id}. Node ids must be unique.',
        );
      }
    }
  }
}

Map<String, dynamic> _encodeNode(SceneNode node) {
  _ensureFiniteTransform2D(node.transform, 'node.transform');
  _ensureNonNegativeDouble(node.hitPadding, 'node.hitPadding');
  _ensureClamped01Double(node.opacity, 'node.opacity');
  final base = <String, dynamic>{
    'id': node.id,
    'type': _nodeTypeToString(node.type),
    'transform': _encodeTransform2D(node.transform),
    'hitPadding': node.hitPadding,
    'opacity': node.opacity,
    'isVisible': node.isVisible,
    'isSelectable': node.isSelectable,
    'isLocked': node.isLocked,
    'isDeletable': node.isDeletable,
    'isTransformable': node.isTransformable,
  };

  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
      _ensureNonNegativeSize(image.size, 'image.size');
      if (image.naturalSize != null) {
        _ensureNonNegativeSize(image.naturalSize!, 'image.naturalSize');
      }
      return {
        ...base,
        'imageId': image.imageId,
        'size': _encodeSize(image.size),
        if (image.naturalSize != null) ...{
          'naturalSize': _encodeSize(image.naturalSize!),
        },
      };
    case NodeType.text:
      final text = node as TextNode;
      _ensureNonNegativeSize(text.size, 'text.size');
      _ensurePositiveDouble(text.fontSize, 'text.fontSize');
      if (text.maxWidth != null) {
        _ensurePositiveDouble(text.maxWidth!, 'text.maxWidth');
      }
      if (text.lineHeight != null) {
        _ensurePositiveDouble(text.lineHeight!, 'text.lineHeight');
      }
      return {
        ...base,
        'text': text.text,
        'size': _encodeSize(text.size),
        'fontSize': text.fontSize,
        'color': _colorToHex(text.color),
        'align': _textAlignToString(text.align),
        'isBold': text.isBold,
        'isItalic': text.isItalic,
        'isUnderline': text.isUnderline,
        if (text.fontFamily != null) 'fontFamily': text.fontFamily,
        if (text.maxWidth != null) 'maxWidth': text.maxWidth,
        if (text.lineHeight != null) 'lineHeight': text.lineHeight,
      };
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      _ensurePositiveDouble(stroke.thickness, 'stroke.thickness');
      return {
        ...base,
        'localPoints': stroke.points
            .map((point) => {'x': point.dx, 'y': point.dy})
            .toList(),
        'thickness': stroke.thickness,
        'color': _colorToHex(stroke.color),
      };
    case NodeType.line:
      final line = node as LineNode;
      _ensurePositiveDouble(line.thickness, 'line.thickness');
      return {
        ...base,
        'localA': {'x': line.start.dx, 'y': line.start.dy},
        'localB': {'x': line.end.dx, 'y': line.end.dy},
        'thickness': line.thickness,
        'color': _colorToHex(line.color),
      };
    case NodeType.rect:
      final rect = node as RectNode;
      _ensureNonNegativeSize(rect.size, 'rect.size');
      _ensureNonNegativeDouble(rect.strokeWidth, 'rect.strokeWidth');
      return {
        ...base,
        'size': _encodeSize(rect.size),
        'strokeWidth': rect.strokeWidth,
        if (rect.fillColor != null) 'fillColor': _colorToHex(rect.fillColor!),
        if (rect.strokeColor != null)
          'strokeColor': _colorToHex(rect.strokeColor!),
      };
    case NodeType.path:
      final path = node as PathNode;
      _ensureNonNegativeDouble(path.strokeWidth, 'path.strokeWidth');
      return {
        ...base,
        'svgPathData': path.svgPathData,
        'fillRule': _pathFillRuleToString(path.fillRule),
        'strokeWidth': path.strokeWidth,
        if (path.fillColor != null) 'fillColor': _colorToHex(path.fillColor!),
        if (path.strokeColor != null)
          'strokeColor': _colorToHex(path.strokeColor!),
      };
  }
}

SceneNode _decodeNode(Map<String, dynamic> json) {
  final type = _parseNodeType(_requireString(json, 'type'));
  final id = _requireString(json, 'id');
  final transform = _decodeTransform2D(_requireMap(json, 'transform'));
  final hitPadding = _requireNonNegativeDouble(json, 'hitPadding');
  final opacity = _requireClamped01Double(json, 'opacity');
  final isVisible = _requireBool(json, 'isVisible');
  final isSelectable = _requireBool(json, 'isSelectable');
  final isLocked = _requireBool(json, 'isLocked');
  final isDeletable = _requireBool(json, 'isDeletable');
  final isTransformable = _requireBool(json, 'isTransformable');

  SceneNode node;
  switch (type) {
    case NodeType.image:
      node = ImageNode(
        id: id,
        imageId: _requireString(json, 'imageId'),
        size: _requireNonNegativeSize(json, 'size'),
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
      break;
    case NodeType.text:
      node = TextNode(
        id: id,
        text: _requireString(json, 'text'),
        size: _requireNonNegativeSize(json, 'size'),
        fontSize: _requirePositiveDouble(json, 'fontSize'),
        color: _parseColor(_requireString(json, 'color')),
        align: _parseTextAlign(_requireString(json, 'align')),
        isBold: _requireBool(json, 'isBold'),
        isItalic: _requireBool(json, 'isItalic'),
        isUnderline: _requireBool(json, 'isUnderline'),
        fontFamily: _optionalString(json, 'fontFamily'),
        maxWidth: _optionalPositiveDouble(json, 'maxWidth'),
        lineHeight: _optionalPositiveDouble(json, 'lineHeight'),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
      recomputeDerivedTextSize(node as TextNode);
      break;
    case NodeType.stroke:
      node = StrokeNode(
        id: id,
        points: _requireList(
          json,
          'localPoints',
        ).map((point) => _parsePoint(point, 'localPoints')).toList(),
        thickness: _requirePositiveDouble(json, 'thickness'),
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
      break;
    case NodeType.line:
      node = LineNode(
        id: id,
        start: _parsePoint(_requireMap(json, 'localA'), 'localA'),
        end: _parsePoint(_requireMap(json, 'localB'), 'localB'),
        thickness: _requirePositiveDouble(json, 'thickness'),
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
      break;
    case NodeType.rect:
      node = RectNode(
        id: id,
        size: _requireNonNegativeSize(json, 'size'),
        fillColor: _optionalColor(json, 'fillColor'),
        strokeColor: _optionalColor(json, 'strokeColor'),
        strokeWidth: _requireNonNegativeDouble(json, 'strokeWidth'),
        hitPadding: hitPadding,
        transform: transform,
        opacity: opacity,
        isVisible: isVisible,
        isSelectable: isSelectable,
        isLocked: isLocked,
        isDeletable: isDeletable,
        isTransformable: isTransformable,
      );
      break;
    case NodeType.path:
      final svgPathData = _requireString(json, 'svgPathData');
      _validateSvgPathData(svgPathData);
      node = PathNode(
        id: id,
        svgPathData: svgPathData,
        fillColor: _optionalColor(json, 'fillColor'),
        strokeColor: _optionalColor(json, 'strokeColor'),
        strokeWidth: _requireNonNegativeDouble(json, 'strokeWidth'),
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
      break;
  }

  return node;
}

String _nodeTypeToString(NodeType type) {
  switch (type) {
    case NodeType.image:
      return 'image';
    case NodeType.text:
      return 'text';
    case NodeType.stroke:
      return 'stroke';
    case NodeType.line:
      return 'line';
    case NodeType.rect:
      return 'rect';
    case NodeType.path:
      return 'path';
  }
}

NodeType _parseNodeType(String value) {
  switch (value) {
    case 'image':
      return NodeType.image;
    case 'text':
      return NodeType.text;
    case 'stroke':
      return NodeType.stroke;
    case 'line':
      return NodeType.line;
    case 'rect':
      return NodeType.rect;
    case 'path':
      return NodeType.path;
    default:
      throw SceneJsonFormatException('Unknown node type: $value.');
  }
}

String _pathFillRuleToString(PathFillRule rule) {
  switch (rule) {
    case PathFillRule.nonZero:
      return 'nonZero';
    case PathFillRule.evenOdd:
      return 'evenOdd';
  }
}

PathFillRule _parsePathFillRule(String value) {
  switch (value) {
    case 'nonZero':
      return PathFillRule.nonZero;
    case 'evenOdd':
      return PathFillRule.evenOdd;
    default:
      throw SceneJsonFormatException('Unknown fillRule: $value.');
  }
}

String _textAlignToString(TextAlign align) {
  switch (align) {
    case TextAlign.left:
      return 'left';
    case TextAlign.center:
      return 'center';
    case TextAlign.right:
      return 'right';
    default:
      throw SceneJsonFormatException('Unsupported TextAlign: $align.');
  }
}

TextAlign _parseTextAlign(String value) {
  switch (value) {
    case 'left':
      return TextAlign.left;
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    default:
      throw SceneJsonFormatException('Unknown text align: $value.');
  }
}

String _colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Color _parseColor(String value) {
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length == 6) {
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed == null) {
      throw SceneJsonFormatException('Invalid color: $value.');
    }
    return Color(parsed);
  }
  if (normalized.length == 8) {
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      throw SceneJsonFormatException('Invalid color: $value.');
    }
    return Color(parsed);
  }
  throw SceneJsonFormatException('Invalid color: $value.');
}

Color? _optionalColor(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw SceneJsonFormatException('Field $key must be a string.');
  }
  return _parseColor(value);
}

Offset _parsePoint(Object value, String field) {
  if (value is! Map<String, dynamic>) {
    throw SceneJsonFormatException('$field must be an object with x/y.');
  }
  return Offset(_requireDouble(value, 'x'), _requireDouble(value, 'y'));
}

Map<String, dynamic> _encodeTransform2D(Transform2D transform) {
  return <String, dynamic>{...transform.toJsonMap()};
}

Transform2D _decodeTransform2D(Map<String, dynamic> json) {
  return Transform2D(
    a: _requireDouble(json, 'a'),
    b: _requireDouble(json, 'b'),
    c: _requireDouble(json, 'c'),
    d: _requireDouble(json, 'd'),
    tx: _requireDouble(json, 'tx'),
    ty: _requireDouble(json, 'ty'),
  );
}

Map<String, dynamic> _encodeSize(Size size) {
  return <String, dynamic>{'w': size.width, 'h': size.height};
}

Size _requireNonNegativeSize(Map<String, dynamic> json, String key) {
  final map = _requireMap(json, key);
  final w = _requireNonNegativeDouble(map, 'w');
  final h = _requireNonNegativeDouble(map, 'h');
  return Size(w, h);
}

Size? _optionalSizeMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map<String, dynamic>) {
    throw SceneJsonFormatException('Field $key must be an object.');
  }
  final width = value['w'];
  final height = value['h'];
  if (width is! num || height is! num) {
    throw SceneJsonFormatException('Optional size must be numeric.');
  }
  final w = width.toDouble();
  final h = height.toDouble();
  if (!w.isFinite || !h.isFinite) {
    throw SceneJsonFormatException('Optional size must be finite.');
  }
  if (w < 0 || h < 0) {
    throw SceneJsonFormatException('Optional size must be non-negative.');
  }
  return Size(w, h);
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw SceneJsonFormatException('Field $key must be a string.');
  }
  return value;
}

double? _optionalDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num) {
    throw SceneJsonFormatException('Field $key must be a number.');
  }
  final out = value.toDouble();
  if (!out.isFinite) {
    throw SceneJsonFormatException('Field $key must be finite.');
  }
  return out;
}

double? _optionalPositiveDouble(Map<String, dynamic> json, String key) {
  final value = _optionalDouble(json, key);
  if (value == null) return null;
  sceneValidatePositiveDouble(
    value,
    field: key,
    onError: _sceneJsonValidationError,
  );
  return value;
}

void _validateSvgPathData(String value) {
  sceneValidateSvgPathData(
    value,
    field: 'svgPathData',
    onError:
        ({
          required Object? value,
          required String field,
          required String message,
        }) {
          if (message == 'must not be empty.') {
            throw SceneJsonFormatException('svgPathData must not be empty.');
          }
          throw SceneJsonFormatException('Invalid svgPathData.');
        },
  );
}

Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw SceneJsonFormatException('Field $key must be an object.');
  }
  return value;
}

List<dynamic> _requireList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw SceneJsonFormatException('Field $key must be a list.');
  }
  return value;
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw SceneJsonFormatException('Field $key must be a string.');
  }
  return value;
}

String _requireStringValue(Object value, String key) {
  if (value is! String) {
    throw SceneJsonFormatException('Items of $key must be strings.');
  }
  return value;
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw SceneJsonFormatException('Field $key must be a bool.');
  }
  return value;
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  // Accept integer-valued finite numbers (e.g. 2 and 2.0) for JSON parsers
  // that materialize integral literals as double.
  if (value is! num) {
    throw SceneJsonFormatException('Field $key must be an int.');
  }
  final asDouble = value.toDouble();
  if (!asDouble.isFinite || asDouble.truncateToDouble() != asDouble) {
    throw SceneJsonFormatException('Field $key must be an int.');
  }
  return value.toInt();
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw SceneJsonFormatException('Field $key must be a number.');
  }
  final out = value.toDouble();
  sceneValidateFiniteDouble(
    out,
    field: key,
    onError: _sceneJsonValidationError,
  );
  return out;
}

double _requireDoubleValue(Object value, String key) {
  if (value is! num) {
    throw SceneJsonFormatException('Items of $key must be numbers.');
  }
  final out = value.toDouble();
  sceneValidateFiniteDouble(
    out,
    field: 'Items of $key',
    onError: _sceneJsonItemsValidationError,
  );
  return out;
}

double _requirePositiveDouble(Map<String, dynamic> json, String key) {
  final value = _requireDouble(json, key);
  sceneValidatePositiveDouble(
    value,
    field: key,
    onError: _sceneJsonValidationError,
  );
  return value;
}

double _requireGridCellSize(Map<String, dynamic> json) {
  final value = _requireDouble(json, 'cellSize');
  sceneValidatePositiveDouble(
    value,
    field: 'cellSize',
    onError: _sceneJsonValidationError,
  );
  return value;
}

double _requireNonNegativeDouble(Map<String, dynamic> json, String key) {
  final value = _requireDouble(json, key);
  sceneValidateNonNegativeDouble(
    value,
    field: key,
    onError: _sceneJsonValidationError,
  );
  return value;
}

double _requireClamped01Double(Map<String, dynamic> json, String key) {
  final value = _requireDouble(json, key);
  sceneValidateClamped01Double(
    value,
    field: key,
    onError: _sceneJsonValidationError,
  );
  return value;
}

double _requirePositiveDoubleValue(Object value, String key) {
  final out = _requireDoubleValue(value, key);
  sceneValidatePositiveDouble(
    out,
    field: 'Items of $key',
    onError: _sceneJsonItemsValidationError,
  );
  return out;
}

void _ensureNonNegativeDouble(double value, String field) {
  sceneValidateNonNegativeDouble(
    value,
    field: field,
    onError: _sceneJsonValidationError,
  );
}

void _ensurePositiveDouble(double value, String field) {
  sceneValidatePositiveDouble(
    value,
    field: field,
    onError: _sceneJsonValidationError,
  );
}

void _ensureClamped01Double(double value, String field) {
  sceneValidateClamped01Double(
    value,
    field: field,
    onError: _sceneJsonValidationError,
  );
}

void _ensureNonNegativeSize(Size size, String field) {
  _ensureNonNegativeDouble(size.width, '$field.w');
  _ensureNonNegativeDouble(size.height, '$field.h');
}

void _ensureFiniteTransform2D(Transform2D transform, String field) {
  sceneValidateFiniteTransform2D(
    transform,
    field: field,
    onError: _sceneJsonValidationError,
  );
}

void _ensureListNotEmpty(List<Object?> values, String field) {
  if (values.isEmpty) {
    throw SceneJsonFormatException('Field $field must not be empty.');
  }
}

Never _sceneJsonValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneJsonFormatException('Field $field $message');
}

Never _sceneJsonItemsValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneJsonFormatException('$field $message');
}
