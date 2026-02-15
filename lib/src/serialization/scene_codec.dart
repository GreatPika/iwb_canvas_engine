import 'dart:convert';
import 'dart:ui';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/transform2d.dart';
import '../model/document.dart';
import '../model/scene_builder.dart' as model_builder;
import '../public/scene_data_exception.dart';
import '../public/snapshot.dart' hide NodeId;

/// JSON schema version written by this package.
const int schemaVersionWrite = 4;

/// JSON schema versions accepted by this package.
const Set<int> schemaVersionsRead = {4};

/// Encodes [snapshot] to a JSON string.
String encodeSceneToJson(SceneSnapshot snapshot) {
  return jsonEncode(encodeScene(snapshot));
}

/// Decodes a [SceneSnapshot] from a JSON string.
///
/// Only `schemaVersion = 4` is accepted.
///
/// Throws [SceneDataException] when the JSON is invalid, the schema version is
/// unsupported, or validation fails.
SceneSnapshot decodeSceneFromJson(String json) {
  try {
    final raw = jsonDecode(json);
    if (raw is! Map) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidJson,
        message: 'Root JSON must be an object.',
      );
    }
    return decodeScene(Map<String, Object?>.from(raw));
  } on SceneDataException {
    rethrow;
  } on FormatException catch (error) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidJson,
      message: error.message,
      source: error.source,
    );
  }
}

/// Encodes [snapshot] into a JSON-serializable map.
Map<String, dynamic> encodeScene(SceneSnapshot snapshot) {
  final canonicalSnapshot = model_builder.sceneCanonicalizeAndValidateSnapshot(
    snapshot,
  );
  return _encodeSnapshot(canonicalSnapshot);
}

/// Decodes a [SceneSnapshot] from a JSON map (already parsed).
///
/// Only `schemaVersion = 4` is accepted.
///
/// Throws [SceneDataException] when validation fails.
SceneSnapshot decodeScene(Map<String, Object?> json) {
  final sceneDoc = decodeSceneDocument(json);
  return txnSceneToSnapshot(sceneDoc);
}

/// Encodes internal mutable [Scene] document into a JSON-serializable map.
Map<String, dynamic> encodeSceneDocument(Scene scene) {
  final canonicalScene = model_builder.sceneValidateCore(scene);
  final backgroundLayer = canonicalScene.backgroundLayer!;
  return <String, dynamic>{
    'schemaVersion': schemaVersionWrite,
    'camera': {
      'offsetX': canonicalScene.camera.offset.dx,
      'offsetY': canonicalScene.camera.offset.dy,
    },
    'background': {
      'color': _colorToHex(canonicalScene.background.color),
      'grid': {
        'enabled': canonicalScene.background.grid.isEnabled,
        'cellSize': canonicalScene.background.grid.cellSize,
        'color': _colorToHex(canonicalScene.background.grid.color),
      },
    },
    'palette': {
      'penColors': canonicalScene.palette.penColors.map(_colorToHex).toList(),
      'backgroundColors': canonicalScene.palette.backgroundColors
          .map(_colorToHex)
          .toList(),
      'gridSizes': canonicalScene.palette.gridSizes,
    },
    'backgroundLayer': _encodeBackgroundLayer(backgroundLayer),
    'layers': canonicalScene.layers.map(_encodeContentLayer).toList(),
  };
}

/// Decodes internal mutable [Scene] document from a JSON map (already parsed).
///
/// Only `schemaVersion = 4` is accepted.
///
/// Throws [SceneDataException] when validation fails.
Scene decodeSceneDocument(Map<String, Object?> json) {
  return model_builder.sceneBuildFromJsonMap(json);
}

Map<String, dynamic> _encodeSnapshot(SceneSnapshot snapshot) {
  final backgroundLayer = snapshot.backgroundLayer;
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
    'backgroundLayer': <String, dynamic>{
      'nodes': backgroundLayer.nodes
          .map((node) => _encodeNode(txnNodeFromSnapshot(node)))
          .toList(),
    },
    'layers': snapshot.layers
        .map(
          (layer) => <String, dynamic>{
            'nodes': layer.nodes
                .map((node) => _encodeNode(txnNodeFromSnapshot(node)))
                .toList(),
          },
        )
        .toList(),
  };
}

Map<String, dynamic> _encodeBackgroundLayer(BackgroundLayer layer) {
  return <String, dynamic>{'nodes': layer.nodes.map(_encodeNode).toList()};
}

Map<String, dynamic> _encodeContentLayer(ContentLayer layer) {
  return <String, dynamic>{'nodes': layer.nodes.map(_encodeNode).toList()};
}

Map<String, dynamic> _encodeNode(SceneNode node) {
  final base = <String, dynamic>{
    'id': node.id,
    'instanceRevision': node.instanceRevision,
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

String _pathFillRuleToString(PathFillRule rule) {
  switch (rule) {
    case PathFillRule.nonZero:
      return 'nonZero';
    case PathFillRule.evenOdd:
      return 'evenOdd';
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
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'Unsupported TextAlign: $align.',
        source: align,
      );
  }
}

String _colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Map<String, dynamic> _encodeTransform2D(Transform2D transform) {
  return <String, dynamic>{...transform.toJsonMap()};
}

Map<String, dynamic> _encodeSize(Size size) {
  return <String, dynamic>{'w': size.width, 'h': size.height};
}
