import 'dart:convert';
import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../core/scene.dart';
import '../core/nodes.dart';
import '../core/transform2d.dart';

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

/// Backwards-compatible alias for the current schema version.
const int schemaVersion = schemaVersionWrite;

/// Encodes [scene] to a JSON string.
String encodeSceneToJson(Scene scene) {
  return jsonEncode(encodeScene(scene));
}

/// Decodes a [Scene] from a JSON string.
///
/// Throws [SceneJsonFormatException] when the JSON is invalid or fails schema
/// validation.
Scene decodeSceneFromJson(String json) {
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

/// Encodes [scene] into a JSON-serializable map.
Map<String, dynamic> encodeScene(Scene scene) {
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

/// Decodes a [Scene] from a JSON map (already parsed).
///
/// Throws [SceneJsonFormatException] when validation fails.
Scene decodeScene(Map<String, dynamic> json) {
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
  final background = Background(
    color: _parseColor(_requireString(backgroundJson, 'color')),
    grid: GridSettings(
      isEnabled: _requireBool(gridJson, 'enabled'),
      cellSize: _requireDouble(gridJson, 'cellSize'),
      color: _parseColor(_requireString(gridJson, 'color')),
    ),
  );

  final paletteJson = _requireMap(json, 'palette');
  final palette = ScenePalette(
    penColors: _requireList(paletteJson, 'penColors')
        .map((value) => _parseColor(_requireStringValue(value, 'penColors')))
        .toList(),
    backgroundColors: _requireList(paletteJson, 'backgroundColors')
        .map(
          (value) =>
              _parseColor(_requireStringValue(value, 'backgroundColors')),
        )
        .toList(),
    gridSizes: _requireList(
      paletteJson,
      'gridSizes',
    ).map((value) => _requireDoubleValue(value, 'gridSizes')).toList(),
  );

  final layersJson = _requireList(json, 'layers');
  final layers = layersJson.map((layerJson) {
    if (layerJson is! Map<String, dynamic>) {
      throw SceneJsonFormatException('Layer must be an object.');
    }
    return _decodeLayer(layerJson);
  }).toList();

  return Scene(
    layers: layers,
    camera: camera,
    background: background,
    palette: palette,
  );
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

Map<String, dynamic> _encodeNode(SceneNode node) {
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
      return {
        ...base,
        'localA': {'x': line.start.dx, 'y': line.start.dy},
        'localB': {'x': line.end.dx, 'y': line.end.dy},
        'thickness': line.thickness,
        'color': _colorToHex(line.color),
      };
    case NodeType.rect:
      final rect = node as RectNode;
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
  final hitPadding = _requireDouble(json, 'hitPadding');
  final opacity = _requireDouble(json, 'opacity');
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
      break;
    case NodeType.text:
      node = TextNode(
        id: id,
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
      break;
    case NodeType.stroke:
      node = StrokeNode(
        id: id,
        points: _requireList(
          json,
          'localPoints',
        ).map((point) => _parsePoint(point, 'localPoints')).toList(),
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
      break;
    case NodeType.line:
      node = LineNode(
        id: id,
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
      break;
    case NodeType.rect:
      node = RectNode(
        id: id,
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
      break;
    case NodeType.path:
      final svgPathData = _requireString(json, 'svgPathData');
      _validateSvgPathData(svgPathData);
      node = PathNode(
        id: id,
        svgPathData: svgPathData,
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
  return <String, dynamic>{
    'a': transform.a,
    'b': transform.b,
    'c': transform.c,
    'd': transform.d,
    'tx': transform.tx,
    'ty': transform.ty,
  };
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

Size _requireSize(Map<String, dynamic> json, String key) {
  final map = _requireMap(json, key);
  return Size(_requireDouble(map, 'w'), _requireDouble(map, 'h'));
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
  return Size(width.toDouble(), height.toDouble());
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
  return value.toDouble();
}

void _validateSvgPathData(String value) {
  if (value.trim().isEmpty) {
    throw SceneJsonFormatException('svgPathData must not be empty.');
  }
  try {
    parseSvgPathData(value);
  } catch (_) {
    throw SceneJsonFormatException('Invalid svgPathData.');
  }
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
  if (value is! int) {
    throw SceneJsonFormatException('Field $key must be an int.');
  }
  return value;
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw SceneJsonFormatException('Field $key must be a number.');
  }
  return value.toDouble();
}

double _requireDoubleValue(Object value, String key) {
  if (value is! num) {
    throw SceneJsonFormatException('Items of $key must be numbers.');
  }
  return value.toDouble();
}
