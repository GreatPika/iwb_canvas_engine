import 'dart:convert';
import 'dart:ui';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/scene_limits.dart'
    show
        kMaxRawSceneJsonLength,
        sceneSchemaVersionWrite,
        sceneSchemaVersionsRead;
import '../contract/transform2d.dart';
import '../model/document.dart';
import '../model/scene_builder.dart' as model_builder;
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';

part 'codec_guards.dart';

/// JSON schema version written by this package.
const int schemaVersionWrite = sceneSchemaVersionWrite;

/// JSON schema versions accepted by this package.
const Set<int> schemaVersionsRead = sceneSchemaVersionsRead;

/// Encodes [snapshot] to a JSON string after validation and canonicalization.
///
/// This is the string-producing serialization gateway on the public boundary.
///
/// Throws [SceneDataException] when [snapshot] violates the public scene
/// contract.
String encodeSceneToJson(SceneSnapshot snapshot) {
  return _guardEncode(() => jsonEncode(encodeScene(snapshot)));
}

/// Decodes a [SceneSnapshot] from a JSON string.
///
/// Only schema versions listed in [schemaVersionsRead] are accepted.
///
/// Throws [SceneDataException] for all public decode failures.
///
/// JSON parse failures and non-object root values are reported with
/// [SceneDataErrorCode.invalidJson]. More specific schema and nested import
/// validation failures are delegated to [decodeScene]. Root-level failures may
/// omit [SceneDataException.path] when the boundary does not yet know a more
/// specific field location.
///
/// Raw JSON strings longer than [kMaxRawSceneJsonLength] characters are
/// rejected before `jsonDecode`.
SceneSnapshot decodeSceneFromJson(String json) {
  final scene = _guardDecode(json, decodeSceneDocument);
  return txnSceneToSnapshot(scene);
}

T debugGuardDecodeForTest<T>(
  String rawJson,
  T Function(Map<String, Object?> raw) decode,
) {
  return _guardDecode(rawJson, decode);
}

T debugGuardEncodeForTest<T>(T Function() encode) {
  return _guardEncode(encode);
}

/// Encodes [snapshot] into a canonical JSON-serializable map.
///
/// This is the parsed-map serialization gateway on the public boundary.
///
/// Throws [SceneDataException] when [snapshot] violates the public scene
/// contract.
Map<String, dynamic> encodeScene(SceneSnapshot snapshot) {
  final canonicalSnapshot = model_builder.sceneCanonicalizeAndValidateSnapshot(
    snapshot,
  );
  return _encodeCanonicalSnapshot(canonicalSnapshot);
}

/// Decodes a [SceneSnapshot] from a parsed JSON map.
///
/// Only schema versions listed in [schemaVersionsRead] are accepted.
///
/// Throws [SceneDataException] when schema or import validation fails.
/// Nested boundary failures include [SceneDataException.path] when the decode
/// boundary knows the exact field location. Root-level failures may omit
/// [SceneDataException.path] when the boundary cannot attribute a more
/// specific field.
SceneSnapshot decodeScene(Map<String, dynamic> json) {
  final sceneDoc = _guardParsedDecode(json, decodeSceneDocument);
  return txnSceneToSnapshot(sceneDoc);
}

/// Encodes internal mutable [Scene] document into a JSON-serializable map.
Map<String, dynamic> encodeSceneDocument(Scene scene) {
  final canonicalScene = model_builder.sceneValidateCore(scene);
  final canonicalSnapshot = txnSceneToSnapshot(canonicalScene);
  return _encodeCanonicalSnapshot(canonicalSnapshot);
}

/// Decodes internal mutable [Scene] document from a JSON map (already parsed).
///
/// Only schema versions listed in [schemaVersionsRead] are accepted.
///
/// Throws [SceneDataException] when validation fails.
Scene decodeSceneDocument(Map<String, Object?> json) {
  return model_builder.sceneBuildFromJsonMap(json);
}

Map<String, dynamic> _encodeCanonicalSnapshot(SceneSnapshot snapshot) {
  final backgroundLayer = snapshot.backgroundLayer;
  final backgroundNodes = <Map<String, dynamic>>[];
  for (
    var nodeIndex = 0;
    nodeIndex < backgroundLayer.nodes.length;
    nodeIndex++
  ) {
    backgroundNodes.add(
      _encodeNode(
        txnNodeFromSnapshot(backgroundLayer.nodes[nodeIndex]),
        nodePath: 'backgroundLayer.nodes[$nodeIndex]',
      ),
    );
  }
  final layers = <Map<String, dynamic>>[];
  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    final nodes = <Map<String, dynamic>>[];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      nodes.add(
        _encodeNode(
          txnNodeFromSnapshot(layer.nodes[nodeIndex]),
          nodePath: 'layers[$layerIndex].nodes[$nodeIndex]',
        ),
      );
    }
    layers.add(<String, dynamic>{'id': layer.id, 'nodes': nodes});
  }
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
    'backgroundLayer': <String, dynamic>{'nodes': backgroundNodes},
    'layers': layers,
  };
}

T _guardParsedDecode<T>(
  Map<String, dynamic> rawJson,
  T Function(Map<String, Object?> raw) decode,
) {
  try {
    return decode(Map<String, Object?>.from(rawJson));
  } on SceneDataException {
    rethrow;
  } on FormatException catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  } catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  }
}

Map<String, dynamic> _encodeNode(SceneNode node, {required String nodePath}) {
  assert(nodePath.isNotEmpty, 'nodePath must not be empty.');
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
      final naturalSize = image.naturalSize;
      return {
        ...base,
        'imageId': image.imageId,
        'size': _encodeSize(image.size),
        if (naturalSize != null) ...{'naturalSize': _encodeSize(naturalSize)},
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
      final fillColor = rect.fillColor;
      final strokeColor = rect.strokeColor;
      return {
        ...base,
        'size': _encodeSize(rect.size),
        'strokeWidth': rect.strokeWidth,
        if (fillColor != null) 'fillColor': _colorToHex(fillColor),
        if (strokeColor != null) 'strokeColor': _colorToHex(strokeColor),
      };
    case NodeType.path:
      final path = node as PathNode;
      final fillColor = path.fillColor;
      final strokeColor = path.strokeColor;
      return {
        ...base,
        'svgPathData': path.svgPathData,
        'fillRule': _pathFillRuleToString(path.fillRule),
        'strokeWidth': path.strokeWidth,
        if (fillColor != null) 'fillColor': _colorToHex(fillColor),
        if (strokeColor != null) 'strokeColor': _colorToHex(strokeColor),
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
    case TextAlign.justify:
      return 'justify';
    case TextAlign.start:
      return 'start';
    case TextAlign.end:
      return 'end';
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
