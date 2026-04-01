import 'dart:convert';
import 'dart:ui';

import '../core/text_layout.dart';
import '../core/scene.dart';
import '../core/scene_limits.dart'
    show
        kMaxRawSceneJsonLength,
        sceneSchemaVersionWrite,
        sceneSchemaVersionsRead;
import '../core/revision_policy.dart';
import '../contract/internal/node_boundary_schema.dart';
import '../contract/transform2d.dart';
import '../model/document.dart';
import '../model/scene_document_codec.dart';
import '../model/scene_builder_api.dart';
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
/// contract. Compare boundary failures by [SceneDataException.code],
/// [SceneDataException.path], and immutable [SceneDataException.details];
/// [SceneDataException.message] is derived user-facing text.
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
/// contract. Compare boundary failures by [SceneDataException.code],
/// [SceneDataException.path], and immutable [SceneDataException.details];
/// [SceneDataException.message] is derived user-facing text.
Map<String, dynamic> encodeScene(SceneSnapshot snapshot) {
  return _guardEncode(() {
    final canonicalSnapshot = SceneBuilder.buildFromSnapshot(snapshot);
    return _encodeCanonicalSnapshot(canonicalSnapshot);
  });
}

/// Decodes a [SceneSnapshot] from a parsed JSON map.
///
/// Only schema versions listed in [schemaVersionsRead] are accepted.
///
/// Throws [SceneDataException] when schema or import validation fails.
/// Nested boundary failures include [SceneDataException.path] when the decode
/// boundary knows the exact field location. Root-level failures may omit
/// [SceneDataException.path] when the boundary cannot attribute a more
/// specific field. Compare boundary failures by [SceneDataException.code],
/// [SceneDataException.path], and immutable [SceneDataException.details];
/// [SceneDataException.message] is derived user-facing text.
SceneSnapshot decodeScene(Map<String, dynamic> json) {
  return SceneBuilder.buildFromJson(json);
}

/// Encodes internal mutable [Scene] document into a JSON-serializable map.
///
/// Compare boundary failures by [SceneDataException.code],
/// [SceneDataException.path], and immutable [SceneDataException.details];
/// [SceneDataException.message] is derived user-facing text.
Map<String, dynamic> encodeSceneDocument(Scene scene) {
  return _guardEncode(() {
    final canonicalScene = sceneValidateDocumentForEncode(scene);
    final canonicalSnapshot = txnSceneToSnapshot(canonicalScene);
    return _encodeCanonicalSnapshot(canonicalSnapshot);
  });
}

/// Decodes internal mutable [Scene] document from a JSON map (already parsed).
///
/// Only schema versions listed in [schemaVersionsRead] are accepted.
///
/// Throws [SceneDataException] when validation fails.
Scene decodeSceneDocument(Map<String, Object?> json) {
  return sceneDecodeDocumentFromJsonMap(json);
}

Map<String, dynamic> _encodeCanonicalSnapshot(SceneSnapshot snapshot) {
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
      'nodes': _encodeLayerNodes(
        snapshot.backgroundLayer.nodes,
        nodesPath: 'backgroundLayer.nodes',
      ),
    },
    'layers': _encodeContentLayers(snapshot.layers),
  };
}

Map<String, dynamic> _encodeNode(
  NodeSnapshot node, {
  required String nodePath,
}) {
  assert(nodePath.isNotEmpty, 'nodePath must not be empty.');
  final encodedFields = switch (node) {
    ImageNodeSnapshot image => _encodeImageFields(image),
    TextNodeSnapshot text => _encodeTextFields(text),
    StrokeNodeSnapshot stroke => _encodeStrokeFields(stroke),
    LineNodeSnapshot line => _encodeLineFields(line),
    RectNodeSnapshot rect => _encodeRectFields(rect),
    PathNodeSnapshot path => _encodePathFields(path),
  };
  return {
    ..._encodeNodeCommonFields(
      common: _snapshotCommonFields(node),
      type: encodedFields.type,
    ),
    ...encodedFields.fields,
  };
}

List<Map<String, dynamic>> _encodeContentLayers(
  List<ContentLayerSnapshot> layers,
) {
  final encodedLayers = <Map<String, dynamic>>[];
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    encodedLayers.add(<String, dynamic>{
      'id': layer.id,
      'nodes': _encodeLayerNodes(
        layer.nodes,
        nodesPath: 'layers[$layerIndex].nodes',
      ),
    });
  }
  return encodedLayers;
}

List<Map<String, dynamic>> _encodeLayerNodes(
  List<NodeSnapshot> nodes, {
  required String nodesPath,
}) {
  final encodedNodes = <Map<String, dynamic>>[];
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    encodedNodes.add(
      _encodeNode(nodes[nodeIndex], nodePath: '$nodesPath[$nodeIndex]'),
    );
  }
  return encodedNodes;
}

({Map<String, dynamic> fields, String type}) _encodeImageFields(
  ImageNodeSnapshot node,
) {
  final fields = imageNodeSchemaFieldsFromValidated((
    imageId: node.imageId,
    size: node.size,
    naturalSize: node.naturalSize,
  ));
  final naturalSize = fields.naturalSize;
  return (
    type: 'image',
    fields: <String, dynamic>{
      'imageId': fields.imageId,
      'size': _encodeSize(fields.size),
      ..._encodeOptionalSizeField('naturalSize', naturalSize),
    },
  );
}

({Map<String, dynamic> fields, String type}) _encodeTextFields(
  TextNodeSnapshot node,
) {
  final fields = textNodeSnapshotSchemaFieldsFromValidated((
    text: node.text,
    size: node.size,
    fontSize: node.fontSize,
    color: node.color,
    align: node.align,
    textDirection: node.textDirection,
    isBold: node.isBold,
    isItalic: node.isItalic,
    isUnderline: node.isUnderline,
    fontFamily: node.fontFamily,
    maxWidth: node.maxWidth,
    lineHeight: node.lineHeight,
  ));
  final canonicalSize = _deriveCanonicalTextSize(fields);
  return (
    type: 'text',
    fields: <String, dynamic>{
      'text': fields.text,
      'size': _encodeSize(canonicalSize),
      'fontSize': fields.fontSize,
      'color': _colorToHex(fields.color),
      'align': _textAlignToString(fields.align),
      'textDirection': _textDirectionToString(fields.textDirection),
      'isBold': fields.isBold,
      'isItalic': fields.isItalic,
      'isUnderline': fields.isUnderline,
      if (fields.fontFamily != null) 'fontFamily': fields.fontFamily,
      if (fields.maxWidth != null) 'maxWidth': fields.maxWidth,
      if (fields.lineHeight != null) 'lineHeight': fields.lineHeight,
    },
  );
}

({Map<String, dynamic> fields, String type}) _encodeStrokeFields(
  StrokeNodeSnapshot node,
) {
  final fields = _strokeNodeSchemaFields(node);
  return _encodeTypedFields(
    'stroke',
    _encodeVectorStrokeFieldMap((
      points: fields.points,
      start: null,
      end: null,
      thickness: fields.thickness,
      color: fields.color,
    )),
  );
}

({Map<String, dynamic> fields, String type}) _encodeLineFields(
  LineNodeSnapshot node,
) {
  final fields = _lineNodeSchemaFields(node);
  return _encodeTypedFields(
    'line',
    _encodeVectorStrokeFieldMap((
      points: null,
      start: fields.start,
      end: fields.end,
      thickness: fields.thickness,
      color: fields.color,
    )),
  );
}

({Map<String, dynamic> fields, String type}) _encodeRectFields(
  RectNodeSnapshot node,
) {
  final fields = _rectNodeSchemaFields(node);
  final fillColor = fields.fillColor;
  final strokeColor = fields.strokeColor;
  return _encodeTypedFields(
    'rect',
    _encodeOutlinedShapeFieldMap((
      size: fields.size,
      svgPathData: null,
      fillRule: null,
      strokeWidth: fields.strokeWidth,
      fillColor: fillColor,
      strokeColor: strokeColor,
    )),
  );
}

({Map<String, dynamic> fields, String type}) _encodePathFields(
  PathNodeSnapshot node,
) {
  final fields = _pathNodeSchemaFields(node);
  final fillColor = fields.fillColor;
  final strokeColor = fields.strokeColor;
  return _encodeTypedFields(
    'path',
    _encodeOutlinedShapeFieldMap((
      size: null,
      svgPathData: fields.svgPathData,
      fillRule: fields.fillRule,
      strokeWidth: fields.strokeWidth,
      fillColor: fillColor,
      strokeColor: strokeColor,
    )),
  );
}

StrokeNodeSnapshotSchemaFields _strokeNodeSchemaFields(
  StrokeNodeSnapshot node,
) => strokeNodeSnapshotSchemaFieldsFromValidated((
  points: node.points,
  pointsRevision: node.pointsRevision,
  thickness: node.thickness,
  color: node.color,
));

LineNodeSchemaFields _lineNodeSchemaFields(LineNodeSnapshot node) =>
    lineNodeSchemaFieldsFromValidated((
      start: node.start,
      end: node.end,
      thickness: node.thickness,
      color: node.color,
    ));

RectNodeSchemaFields _rectNodeSchemaFields(RectNodeSnapshot node) =>
    rectNodeSchemaFieldsFromValidated((
      size: node.size,
      fillColor: node.fillColor,
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
    ));

PathNodeSchemaFields _pathNodeSchemaFields(PathNodeSnapshot node) =>
    pathNodeSchemaFieldsFromValidated((
      svgPathData: node.svgPathData,
      fillColor: node.fillColor,
      strokeColor: node.strokeColor,
      strokeWidth: node.strokeWidth,
      fillRule: node.fillRule,
    ));

NodeSnapshotCommonSchemaFields _snapshotCommonFields(NodeSnapshot node) {
  return snapshotCommonSchemaFieldsFromValidated((
    id: node.id,
    instanceRevision: resolveSnapshotInstanceRevision(node.instanceRevision),
    transform: node.transform,
    opacity: node.opacity,
    hitPadding: node.hitPadding,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    isLocked: node.isLocked,
    isDeletable: node.isDeletable,
    isTransformable: node.isTransformable,
  ));
}

Map<String, dynamic> _encodeNodeCommonFields({
  required NodeSnapshotCommonSchemaFields common,
  required String type,
}) {
  return <String, dynamic>{
    'id': common.id,
    'instanceRevision': common.instanceRevision,
    'type': type,
    'transform': _encodeTransform2D(common.transform),
    'hitPadding': common.hitPadding,
    'opacity': common.opacity,
    'isVisible': common.isVisible,
    'isSelectable': common.isSelectable,
    'isLocked': common.isLocked,
    'isDeletable': common.isDeletable,
    'isTransformable': common.isTransformable,
  };
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

String _textDirectionToString(TextDirection direction) {
  switch (direction) {
    case TextDirection.ltr:
      return 'ltr';
    case TextDirection.rtl:
      return 'rtl';
  }
}

String _colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Map<String, dynamic> _encodeOptionalSizeField(String key, Size? size) {
  return size == null ? const <String, dynamic>{} : {key: _encodeSize(size)};
}

Map<String, dynamic> _encodeOptionalColorField(String key, Color? color) {
  return color == null ? const <String, dynamic>{} : {key: _colorToHex(color)};
}

Map<String, dynamic> _encodeStrokeStyleFields({
  required double thickness,
  required Color color,
}) {
  return <String, dynamic>{'thickness': thickness, 'color': _colorToHex(color)};
}

({Map<String, dynamic> fields, String type}) _encodeTypedFields(
  String type,
  Map<String, dynamic> fields,
) {
  return (type: type, fields: fields);
}

Map<String, dynamic> _encodeVectorStrokeFieldMap(
  ({
    Color color,
    Offset? end,
    List<Offset>? points,
    Offset? start,
    double thickness,
  })
  fields,
) {
  final points = fields.points;
  final start = fields.start;
  final end = fields.end;
  return <String, dynamic>{
    if (points != null) 'localPoints': points.map(_encodeOffset).toList(),
    if (start != null) 'localA': _encodeOffset(start),
    if (end != null) 'localB': _encodeOffset(end),
    ..._encodeStrokeStyleFields(
      thickness: fields.thickness,
      color: fields.color,
    ),
  };
}

Map<String, dynamic> _encodeFillAndStrokeFields({
  required double strokeWidth,
  required Color? fillColor,
  required Color? strokeColor,
}) {
  return <String, dynamic>{
    'strokeWidth': strokeWidth,
    ..._encodeOptionalColorField('fillColor', fillColor),
    ..._encodeOptionalColorField('strokeColor', strokeColor),
  };
}

Map<String, dynamic> _encodeOutlinedShapeFieldMap(
  ({
    Color? fillColor,
    PathFillRule? fillRule,
    Size? size,
    String? svgPathData,
    Color? strokeColor,
    double strokeWidth,
  })
  fields,
) {
  final size = fields.size;
  final fillRule = fields.fillRule;
  return <String, dynamic>{
    if (size != null) 'size': _encodeSize(size),
    if (fields.svgPathData != null) 'svgPathData': fields.svgPathData,
    if (fillRule != null) 'fillRule': _pathFillRuleToString(fillRule),
    ..._encodeFillAndStrokeFields(
      strokeWidth: fields.strokeWidth,
      fillColor: fields.fillColor,
      strokeColor: fields.strokeColor,
    ),
  };
}

Map<String, double> _encodeOffset(Offset offset) {
  return <String, double>{'x': offset.dx, 'y': offset.dy};
}

Size _deriveCanonicalTextSize(TextNodeSnapshotSchemaFields fields) {
  return TextLayoutRequest(
    text: fields.text,
    color: fields.color,
    fontSize: fields.fontSize,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    textAlign: fields.align,
    fontFamily: fields.fontFamily,
    lineHeight: fields.lineHeight,
    maxWidth: fields.maxWidth,
    textDirection: fields.textDirection,
  ).measure();
}

Map<String, dynamic> _encodeTransform2D(Transform2D transform) {
  return <String, dynamic>{...transform.toJsonMap()};
}

Map<String, dynamic> _encodeSize(Size size) {
  return <String, dynamic>{'w': size.width, 'h': size.height};
}
