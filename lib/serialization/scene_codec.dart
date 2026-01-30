import 'dart:convert';
import 'dart:ui';

import '../core/scene.dart';
import '../core/nodes.dart';

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

const int schemaVersion = 1;

String encodeSceneToJson(Scene scene) {
  return jsonEncode(encodeScene(scene));
}

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

Map<String, dynamic> encodeScene(Scene scene) {
  return <String, dynamic>{
    'schemaVersion': schemaVersion,
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
      'backgroundColors': scene.palette.backgroundColors.map(_colorToHex).toList(),
      'gridSizes': scene.palette.gridSizes,
    },
    'layers': scene.layers.map(_encodeLayer).toList(),
  };
}

Scene decodeScene(Map<String, dynamic> json) {
  final version = _requireInt(json, 'schemaVersion');
  if (version != schemaVersion) {
    throw SceneJsonFormatException(
      'Unsupported schemaVersion: $version. Expected $schemaVersion.',
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
        .map((value) =>
            _parseColor(_requireStringValue(value, 'backgroundColors')))
        .toList(),
    gridSizes: _requireList(paletteJson, 'gridSizes')
        .map((value) => _requireDoubleValue(value, 'gridSizes'))
        .toList(),
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
  return Layer(
    nodes: nodes,
    isBackground: _requireBool(json, 'isBackground'),
  );
}

Map<String, dynamic> _encodeNode(SceneNode node) {
  final base = <String, dynamic>{
    'id': node.id,
    'type': _nodeTypeToString(node.type),
    'position': {
      'x': node.position.dx,
      'y': node.position.dy,
    },
    'rotationDeg': node.rotationDeg,
    'scaleX': node.scaleX,
    'scaleY': node.scaleY,
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
        'width': image.size.width,
        'height': image.size.height,
        if (image.naturalSize != null) ...{
          'naturalWidth': image.naturalSize!.width,
          'naturalHeight': image.naturalSize!.height,
        },
      };
    case NodeType.text:
      final text = node as TextNode;
      return {
        ...base,
        'text': text.text,
        'width': text.size.width,
        'height': text.size.height,
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
        'points': stroke.points
            .map((point) => {'x': point.dx, 'y': point.dy})
            .toList(),
        'thickness': stroke.thickness,
        'color': _colorToHex(stroke.color),
      };
    case NodeType.line:
      final line = node as LineNode;
      return {
        ...base,
        'start': {'x': line.start.dx, 'y': line.start.dy},
        'end': {'x': line.end.dx, 'y': line.end.dy},
        'thickness': line.thickness,
        'color': _colorToHex(line.color),
      };
    case NodeType.rect:
      final rect = node as RectNode;
      return {
        ...base,
        'width': rect.size.width,
        'height': rect.size.height,
        'strokeWidth': rect.strokeWidth,
        if (rect.fillColor != null) 'fillColor': _colorToHex(rect.fillColor!),
        if (rect.strokeColor != null)
          'strokeColor': _colorToHex(rect.strokeColor!),
      };
  }
}

SceneNode _decodeNode(Map<String, dynamic> json) {
  final type = _parseNodeType(_requireString(json, 'type'));
  final positionJson = _requireMap(json, 'position');
  final position = Offset(
    _requireDouble(positionJson, 'x'),
    _requireDouble(positionJson, 'y'),
  );

  SceneNode node;
  switch (type) {
    case NodeType.image:
      node = ImageNode(
        id: _requireString(json, 'id'),
        imageId: _requireString(json, 'imageId'),
        size: Size(
          _requireDouble(json, 'width'),
          _requireDouble(json, 'height'),
        ),
        naturalSize: _optionalSize(json, 'naturalWidth', 'naturalHeight'),
      );
      break;
    case NodeType.text:
      node = TextNode(
        id: _requireString(json, 'id'),
        text: _requireString(json, 'text'),
        size: Size(
          _requireDouble(json, 'width'),
          _requireDouble(json, 'height'),
        ),
        fontSize: _requireDouble(json, 'fontSize'),
        color: _parseColor(_requireString(json, 'color')),
        align: _parseTextAlign(_requireString(json, 'align')),
        isBold: _requireBool(json, 'isBold'),
        isItalic: _requireBool(json, 'isItalic'),
        isUnderline: _requireBool(json, 'isUnderline'),
        fontFamily: _optionalString(json, 'fontFamily'),
        maxWidth: _optionalDouble(json, 'maxWidth'),
        lineHeight: _optionalDouble(json, 'lineHeight'),
      );
      break;
    case NodeType.stroke:
      node = StrokeNode(
        id: _requireString(json, 'id'),
        points: _requireList(json, 'points')
            .map((point) => _parsePoint(point, 'points'))
            .toList(),
        thickness: _requireDouble(json, 'thickness'),
        color: _parseColor(_requireString(json, 'color')),
      );
      break;
    case NodeType.line:
      node = LineNode(
        id: _requireString(json, 'id'),
        start: _parsePoint(_requireMap(json, 'start'), 'start'),
        end: _parsePoint(_requireMap(json, 'end'), 'end'),
        thickness: _requireDouble(json, 'thickness'),
        color: _parseColor(_requireString(json, 'color')),
      );
      break;
    case NodeType.rect:
      node = RectNode(
        id: _requireString(json, 'id'),
        size: Size(
          _requireDouble(json, 'width'),
          _requireDouble(json, 'height'),
        ),
        fillColor: _optionalColor(json, 'fillColor'),
        strokeColor: _optionalColor(json, 'strokeColor'),
        strokeWidth: _requireDouble(json, 'strokeWidth'),
      );
      break;
  }

  node.position = position;
  node.rotationDeg = _requireDouble(json, 'rotationDeg');
  node.scaleX = _requireDouble(json, 'scaleX');
  node.scaleY = _requireDouble(json, 'scaleY');
  node.opacity = _requireDouble(json, 'opacity');
  node.isVisible = _requireBool(json, 'isVisible');
  node.isSelectable = _requireBool(json, 'isSelectable');
  node.isLocked = _requireBool(json, 'isLocked');
  node.isDeletable = _requireBool(json, 'isDeletable');
  node.isTransformable = _requireBool(json, 'isTransformable');

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
    default:
      throw SceneJsonFormatException('Unknown node type: $value.');
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
  return Offset(
    _requireDouble(value, 'x'),
    _requireDouble(value, 'y'),
  );
}

Size? _optionalSize(Map<String, dynamic> json, String widthKey, String heightKey) {
  final width = json[widthKey];
  final height = json[heightKey];
  if (width == null || height == null) return null;
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
