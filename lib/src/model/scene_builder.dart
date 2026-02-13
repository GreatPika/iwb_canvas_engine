import 'dart:math' as math;
import 'dart:ui';

import '../core/background_layer_invariants.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/scene_limits.dart';
import '../core/text_layout.dart';
import '../core/transform2d.dart';
import '../public/scene_data_exception.dart';
import '../public/snapshot.dart' hide NodeId;
import 'scene_value_validation.dart';

Scene sceneBuildFromSnapshot(
  SceneSnapshot rawSnapshot, {
  int Function()? nextInstanceRevision,
}) {
  final canonicalSnapshot = sceneCanonicalizeAndValidateSnapshot(rawSnapshot);
  return _sceneFromSnapshot(
    canonicalSnapshot,
    nextInstanceRevision: nextInstanceRevision,
  );
}

Scene sceneBuildFromJsonMap(Map<String, Object?> rawJson) {
  try {
    final rawSnapshot = _decodeSnapshotFromJson(rawJson);
    return sceneBuildFromSnapshot(rawSnapshot);
  } on SceneDataException {
    rethrow;
  } catch (error) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidJson,
      message: 'Invalid scene JSON payload.',
      source: error,
    );
  }
}

SceneSnapshot sceneCanonicalizeAndValidateSnapshot(SceneSnapshot rawSnapshot) {
  final canonicalSnapshot = canonicalizeBackgroundLayerSnapshot(rawSnapshot);
  _validateStructuralInvariants(canonicalSnapshot);
  sceneValidateSnapshotValues(
    canonicalSnapshot,
    onError: _snapshotValidationError,
    requirePositiveGridCellSize: true,
  );
  _validateSnapshotRanges(canonicalSnapshot);
  return canonicalSnapshot;
}

Scene sceneCanonicalizeAndValidateScene(Scene rawScene) {
  sceneValidateSceneValues(
    rawScene,
    onError: _sceneValidationError,
    requirePositiveGridCellSize: true,
  );
  final rawSnapshot = _snapshotFromScene(rawScene);
  final canonicalSnapshot = sceneCanonicalizeAndValidateSnapshot(rawSnapshot);
  return _sceneFromSnapshot(canonicalSnapshot);
}

Scene sceneValidateCore(Scene scene) {
  return sceneCanonicalizeAndValidateScene(scene);
}

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

Scene _sceneFromSnapshot(
  SceneSnapshot snapshot, {
  int Function()? nextInstanceRevision,
}) {
  final instanceRevisionAllocator =
      nextInstanceRevision ?? _snapshotInstanceRevisionAllocator(snapshot);
  return Scene(
    backgroundLayer: snapshot.backgroundLayer == null
        ? null
        : BackgroundLayer(
            nodes: snapshot.backgroundLayer!.nodes
                .map(
                  (node) => _sceneNodeFromSnapshot(
                    node,
                    nextInstanceRevision: instanceRevisionAllocator,
                  ),
                )
                .toList(growable: false),
          ),
    layers: snapshot.layers
        .map(
          (layer) => ContentLayer(
            nodes: layer.nodes
                .map(
                  (node) => _sceneNodeFromSnapshot(
                    node,
                    nextInstanceRevision: instanceRevisionAllocator,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
    camera: Camera(offset: snapshot.camera.offset),
    background: Background(
      color: snapshot.background.color,
      grid: GridSettings(
        isEnabled: snapshot.background.grid.isEnabled,
        cellSize: snapshot.background.grid.cellSize,
        color: snapshot.background.grid.color,
      ),
    ),
    palette: ScenePalette(
      penColors: snapshot.palette.penColors,
      backgroundColors: snapshot.palette.backgroundColors,
      gridSizes: snapshot.palette.gridSizes,
    ),
  );
}

SceneNode _sceneNodeFromSnapshot(
  NodeSnapshot node, {
  required int Function() nextInstanceRevision,
}) {
  final instanceRevision = _resolveSnapshotInstanceRevision(
    node,
    nextInstanceRevision: nextInstanceRevision,
  );
  switch (node) {
    case ImageNodeSnapshot image:
      return ImageNode(
        id: image.id,
        instanceRevision: instanceRevision,
        imageId: image.imageId,
        size: image.size,
        naturalSize: image.naturalSize,
        transform: image.transform,
        opacity: image.opacity,
        hitPadding: image.hitPadding,
        isVisible: image.isVisible,
        isSelectable: image.isSelectable,
        isLocked: image.isLocked,
        isDeletable: image.isDeletable,
        isTransformable: image.isTransformable,
      );
    case TextNodeSnapshot text:
      final built = TextNode(
        id: text.id,
        instanceRevision: instanceRevision,
        text: text.text,
        size: text.size,
        fontSize: text.fontSize,
        color: text.color,
        align: text.align,
        isBold: text.isBold,
        isItalic: text.isItalic,
        isUnderline: text.isUnderline,
        fontFamily: text.fontFamily,
        maxWidth: text.maxWidth,
        lineHeight: text.lineHeight,
        transform: text.transform,
        opacity: text.opacity,
        hitPadding: text.hitPadding,
        isVisible: text.isVisible,
        isSelectable: text.isSelectable,
        isLocked: text.isLocked,
        isDeletable: text.isDeletable,
        isTransformable: text.isTransformable,
      );
      recomputeDerivedTextSize(built);
      return built;
    case StrokeNodeSnapshot stroke:
      return StrokeNode(
        id: stroke.id,
        instanceRevision: instanceRevision,
        points: stroke.points,
        pointsRevision: stroke.pointsRevision,
        thickness: stroke.thickness,
        color: stroke.color,
        transform: stroke.transform,
        opacity: stroke.opacity,
        hitPadding: stroke.hitPadding,
        isVisible: stroke.isVisible,
        isSelectable: stroke.isSelectable,
        isLocked: stroke.isLocked,
        isDeletable: stroke.isDeletable,
        isTransformable: stroke.isTransformable,
      );
    case LineNodeSnapshot line:
      return LineNode(
        id: line.id,
        instanceRevision: instanceRevision,
        start: line.start,
        end: line.end,
        thickness: line.thickness,
        color: line.color,
        transform: line.transform,
        opacity: line.opacity,
        hitPadding: line.hitPadding,
        isVisible: line.isVisible,
        isSelectable: line.isSelectable,
        isLocked: line.isLocked,
        isDeletable: line.isDeletable,
        isTransformable: line.isTransformable,
      );
    case RectNodeSnapshot rect:
      return RectNode(
        id: rect.id,
        instanceRevision: instanceRevision,
        size: rect.size,
        fillColor: rect.fillColor,
        strokeColor: rect.strokeColor,
        strokeWidth: rect.strokeWidth,
        transform: rect.transform,
        opacity: rect.opacity,
        hitPadding: rect.hitPadding,
        isVisible: rect.isVisible,
        isSelectable: rect.isSelectable,
        isLocked: rect.isLocked,
        isDeletable: rect.isDeletable,
        isTransformable: rect.isTransformable,
      );
    case PathNodeSnapshot path:
      return PathNode(
        id: path.id,
        instanceRevision: instanceRevision,
        svgPathData: path.svgPathData,
        fillColor: path.fillColor,
        strokeColor: path.strokeColor,
        strokeWidth: path.strokeWidth,
        fillRule: _pathFillRuleFromV2(path.fillRule),
        transform: path.transform,
        opacity: path.opacity,
        hitPadding: path.hitPadding,
        isVisible: path.isVisible,
        isSelectable: path.isSelectable,
        isLocked: path.isLocked,
        isDeletable: path.isDeletable,
        isTransformable: path.isTransformable,
      );
  }
}

SceneSnapshot _snapshotFromScene(Scene scene) {
  return SceneSnapshot(
    backgroundLayer: scene.backgroundLayer == null
        ? null
        : BackgroundLayerSnapshot(
            nodes: scene.backgroundLayer!.nodes
                .map(_snapshotNodeFromScene)
                .toList(growable: false),
          ),
    layers: scene.layers
        .map(
          (layer) => ContentLayerSnapshot(
            nodes: layer.nodes
                .map(_snapshotNodeFromScene)
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
    camera: CameraSnapshot(offset: scene.camera.offset),
    background: BackgroundSnapshot(
      color: scene.background.color,
      grid: GridSnapshot(
        isEnabled: scene.background.grid.isEnabled,
        cellSize: scene.background.grid.cellSize,
        color: scene.background.grid.color,
      ),
    ),
    palette: ScenePaletteSnapshot(
      penColors: scene.palette.penColors,
      backgroundColors: scene.palette.backgroundColors,
      gridSizes: scene.palette.gridSizes,
    ),
  );
}

NodeSnapshot _snapshotNodeFromScene(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
      return ImageNodeSnapshot(
        id: image.id,
        instanceRevision: image.instanceRevision,
        imageId: image.imageId,
        size: image.size,
        naturalSize: image.naturalSize,
        transform: image.transform,
        opacity: image.opacity,
        hitPadding: image.hitPadding,
        isVisible: image.isVisible,
        isSelectable: image.isSelectable,
        isLocked: image.isLocked,
        isDeletable: image.isDeletable,
        isTransformable: image.isTransformable,
      );
    case NodeType.text:
      final text = node as TextNode;
      return TextNodeSnapshot(
        id: text.id,
        instanceRevision: text.instanceRevision,
        text: text.text,
        size: text.size,
        fontSize: text.fontSize,
        color: text.color,
        align: text.align,
        isBold: text.isBold,
        isItalic: text.isItalic,
        isUnderline: text.isUnderline,
        fontFamily: text.fontFamily,
        maxWidth: text.maxWidth,
        lineHeight: text.lineHeight,
        transform: text.transform,
        opacity: text.opacity,
        hitPadding: text.hitPadding,
        isVisible: text.isVisible,
        isSelectable: text.isSelectable,
        isLocked: text.isLocked,
        isDeletable: text.isDeletable,
        isTransformable: text.isTransformable,
      );
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      return StrokeNodeSnapshot(
        id: stroke.id,
        instanceRevision: stroke.instanceRevision,
        points: stroke.points,
        pointsRevision: stroke.pointsRevision,
        thickness: stroke.thickness,
        color: stroke.color,
        transform: stroke.transform,
        opacity: stroke.opacity,
        hitPadding: stroke.hitPadding,
        isVisible: stroke.isVisible,
        isSelectable: stroke.isSelectable,
        isLocked: stroke.isLocked,
        isDeletable: stroke.isDeletable,
        isTransformable: stroke.isTransformable,
      );
    case NodeType.line:
      final line = node as LineNode;
      return LineNodeSnapshot(
        id: line.id,
        instanceRevision: line.instanceRevision,
        start: line.start,
        end: line.end,
        thickness: line.thickness,
        color: line.color,
        transform: line.transform,
        opacity: line.opacity,
        hitPadding: line.hitPadding,
        isVisible: line.isVisible,
        isSelectable: line.isSelectable,
        isLocked: line.isLocked,
        isDeletable: line.isDeletable,
        isTransformable: line.isTransformable,
      );
    case NodeType.rect:
      final rect = node as RectNode;
      return RectNodeSnapshot(
        id: rect.id,
        instanceRevision: rect.instanceRevision,
        size: rect.size,
        fillColor: rect.fillColor,
        strokeColor: rect.strokeColor,
        strokeWidth: rect.strokeWidth,
        transform: rect.transform,
        opacity: rect.opacity,
        hitPadding: rect.hitPadding,
        isVisible: rect.isVisible,
        isSelectable: rect.isSelectable,
        isLocked: rect.isLocked,
        isDeletable: rect.isDeletable,
        isTransformable: rect.isTransformable,
      );
    case NodeType.path:
      final path = node as PathNode;
      return PathNodeSnapshot(
        id: path.id,
        instanceRevision: path.instanceRevision,
        svgPathData: path.svgPathData,
        fillColor: path.fillColor,
        strokeColor: path.strokeColor,
        strokeWidth: path.strokeWidth,
        fillRule: _pathFillRuleToV2(path.fillRule),
        transform: path.transform,
        opacity: path.opacity,
        hitPadding: path.hitPadding,
        isVisible: path.isVisible,
        isSelectable: path.isSelectable,
        isLocked: path.isLocked,
        isDeletable: path.isDeletable,
        isTransformable: path.isTransformable,
      );
  }
}

int Function() _snapshotInstanceRevisionAllocator(SceneSnapshot snapshot) {
  var next = _snapshotInitialNodeInstanceRevisionSeed(snapshot);
  return () {
    final out = next;
    next = next + 1;
    return out;
  };
}

int _snapshotInitialNodeInstanceRevisionSeed(SceneSnapshot snapshot) {
  var maxRevision = 0;
  final backgroundLayer = snapshot.backgroundLayer;
  if (backgroundLayer != null) {
    for (final node in backgroundLayer.nodes) {
      if (node.instanceRevision > maxRevision) {
        maxRevision = node.instanceRevision;
      }
    }
  }
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (node.instanceRevision > maxRevision) {
        maxRevision = node.instanceRevision;
      }
    }
  }
  return maxRevision + 1;
}

int _resolveSnapshotInstanceRevision(
  NodeSnapshot node, {
  required int Function() nextInstanceRevision,
}) {
  final existing = node.instanceRevision;
  if (existing > 0) {
    return existing;
  }
  return nextInstanceRevision();
}

void _validateStructuralInvariants(SceneSnapshot snapshot) {
  final seen = <String>{};

  final backgroundLayer = snapshot.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final node = backgroundLayer.nodes[nodeIndex];
      if (seen.add(node.id)) continue;
      throw SceneDataException(
        code: SceneDataErrorCode.duplicateNodeId,
        path: 'backgroundLayer.nodes[$nodeIndex].id',
        message: 'Must be unique across scene layers.',
        source: node.id,
      );
    }
  }

  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final node = layer.nodes[nodeIndex];
      if (seen.add(node.id)) continue;
      throw SceneDataException(
        code: SceneDataErrorCode.duplicateNodeId,
        path: 'layers[$layerIndex].nodes[$nodeIndex].id',
        message: 'Must be unique across scene layers.',
        source: node.id,
      );
    }
  }
}

void _validateSnapshotRanges(SceneSnapshot snapshot) {
  _validateCoordinate(snapshot.camera.offset.dx, 'camera.offset.dx');
  _validateCoordinate(snapshot.camera.offset.dy, 'camera.offset.dy');

  _validateSizeUpper(
    snapshot.background.grid.cellSize,
    'background.grid.cellSize',
  );
  for (var i = 0; i < snapshot.palette.gridSizes.length; i++) {
    _validateSizeUpper(snapshot.palette.gridSizes[i], 'palette.gridSizes[$i]');
  }

  final backgroundLayer = snapshot.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final field = 'backgroundLayer.nodes[$nodeIndex]';
      _validateNodeRanges(backgroundLayer.nodes[nodeIndex], field);
    }
  }

  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final field = 'layers[$layerIndex].nodes[$nodeIndex]';
      _validateNodeRanges(layer.nodes[nodeIndex], field);
    }
  }
}

void _validateNodeRanges(NodeSnapshot node, String field) {
  _validateTransformRanges(node.transform, '$field.transform');
  _validateInRange(
    node.hitPadding,
    min: 0,
    max: sceneHitPaddingMax,
    path: '$field.hitPadding',
  );

  switch (node) {
    case ImageNodeSnapshot image:
      _validateSize(image.size.width, '$field.size.w');
      _validateSize(image.size.height, '$field.size.h');
      final naturalSize = image.naturalSize;
      if (naturalSize != null) {
        _validateSize(naturalSize.width, '$field.naturalSize.w');
        _validateSize(naturalSize.height, '$field.naturalSize.h');
      }
    case TextNodeSnapshot text:
      _validateSize(text.size.width, '$field.size.w');
      _validateSize(text.size.height, '$field.size.h');
      _validateInRange(
        text.fontSize,
        min: 0,
        max: sceneSizeMax,
        path: '$field.fontSize',
      );
      final maxWidth = text.maxWidth;
      if (maxWidth != null) {
        _validateInRange(
          maxWidth,
          min: 0,
          max: sceneSizeMax,
          path: '$field.maxWidth',
        );
      }
      final lineHeight = text.lineHeight;
      if (lineHeight != null) {
        _validateInRange(
          lineHeight,
          min: 0,
          max: sceneSizeMax,
          path: '$field.lineHeight',
        );
      }
    case StrokeNodeSnapshot stroke:
      _validateInRange(
        stroke.thickness,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.thickness',
      );
      for (var i = 0; i < stroke.points.length; i++) {
        _validateCoordinate(stroke.points[i].dx, '$field.points[$i].x');
        _validateCoordinate(stroke.points[i].dy, '$field.points[$i].y');
      }
    case LineNodeSnapshot line:
      _validateInRange(
        line.thickness,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.thickness',
      );
      _validateCoordinate(line.start.dx, '$field.start.x');
      _validateCoordinate(line.start.dy, '$field.start.y');
      _validateCoordinate(line.end.dx, '$field.end.x');
      _validateCoordinate(line.end.dy, '$field.end.y');
    case RectNodeSnapshot rect:
      _validateSize(rect.size.width, '$field.size.w');
      _validateSize(rect.size.height, '$field.size.h');
      _validateInRange(
        rect.strokeWidth,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.strokeWidth',
      );
    case PathNodeSnapshot path:
      _validateInRange(
        path.strokeWidth,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.strokeWidth',
      );
  }
}

void _validateTransformRanges(Transform2D transform, String path) {
  _validateCoordinate(transform.tx, '$path.tx');
  _validateCoordinate(transform.ty, '$path.ty');

  final scaleX = math.sqrt(
    transform.a * transform.a + transform.b * transform.b,
  );
  final scaleY = math.sqrt(
    transform.c * transform.c + transform.d * transform.d,
  );
  _validateInRange(
    scaleX,
    min: sceneScaleMin,
    max: sceneScaleMax,
    path: '$path.scaleX',
  );
  _validateInRange(
    scaleY,
    min: sceneScaleMin,
    max: sceneScaleMax,
    path: '$path.scaleY',
  );
}

void _validateCoordinate(double value, String path) {
  _validateInRange(value, min: sceneCoordMin, max: sceneCoordMax, path: path);
}

void _validateSize(double value, String path) {
  _validateInRange(value, min: 0, max: sceneSizeMax, path: path);
}

void _validateSizeUpper(double value, String path) {
  _validateInRange(value, min: 0, max: sceneSizeMax, path: path);
}

void _validateInRange(
  double value, {
  required double min,
  required double max,
  required String path,
}) {
  if (value >= min && value <= max) return;
  throw SceneDataException(
    code: SceneDataErrorCode.outOfRange,
    path: path,
    message: 'Field $path must be within [$min, $max].',
    source: value,
  );
}

Never _snapshotValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: field,
    message: 'Field $field $message',
    source: value,
  );
}

Never _sceneValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: field,
    message: 'Field $field $message',
    source: value,
  );
}

Map<String, Object?> _castMap(Map value) {
  final out = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidFieldType,
        message: 'JSON object keys must be strings.',
      );
    }
    out[key] = entry.value;
  }
  return out;
}

Map<String, Object?> _requireMap(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be an object.',
    );
  }
  final value = json[key];
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an object.',
    );
  }
  return _castMap(value);
}

List<Object?> _requireList(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a list.',
    );
  }
  final value = json[key];
  if (value is! List) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a list.',
    );
  }
  return List<Object?>.from(value);
}

String _requireString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  final value = json[key];
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  return value;
}

String _requireStringValue(Object? value, String key) {
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Items of $key must be strings.',
    );
  }
  return value;
}

bool _requireBool(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a bool.',
    );
  }
  final value = json[key];
  if (value is! bool) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a bool.',
    );
  }
  return value;
}

int _requireInt(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  final asDouble = value.toDouble();
  if (!asDouble.isFinite || asDouble.truncateToDouble() != asDouble) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  if (asDouble.abs() > 9007199254740991) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be an int.',
      source: value,
    );
  }
  return asDouble.toInt();
}

double _requireDouble(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a number.',
    );
  }
  final value = json[key];
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a number.',
    );
  }
  final out = value.toDouble();
  if (!out.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be finite.',
      source: value,
    );
  }
  return out;
}

double _requireDoubleValue(Object? value, String key) {
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Items of $key must be numbers.',
    );
  }
  final out = value.toDouble();
  if (!out.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Items of $key must be finite.',
      source: value,
    );
  }
  return out;
}

Transform2D _decodeTransform2D(Map<String, Object?> json) {
  return Transform2D(
    a: _requireDouble(json, 'a'),
    b: _requireDouble(json, 'b'),
    c: _requireDouble(json, 'c'),
    d: _requireDouble(json, 'd'),
    tx: _requireDouble(json, 'tx'),
    ty: _requireDouble(json, 'ty'),
  );
}

Size _requireSize(Map<String, Object?> json, String key) {
  final map = _requireMap(json, key);
  return Size(_requireDouble(map, 'w'), _requireDouble(map, 'h'));
}

Size? _optionalSizeMap(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an object.',
    );
  }
  final parsed = _castMap(value);
  final width = parsed['w'];
  final height = parsed['h'];
  if (width is! num || height is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Optional size must be numeric.',
    );
  }
  final w = width.toDouble();
  final h = height.toDouble();
  if (!w.isFinite || !h.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Optional size must be finite.',
    );
  }
  return Size(w, h);
}

String? _optionalString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  return value;
}

double? _optionalDouble(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a number.',
    );
  }
  final out = value.toDouble();
  if (!out.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be finite.',
      source: value,
    );
  }
  return out;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is int) {
    return value;
  }
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  final asDouble = value.toDouble();
  if (!asDouble.isFinite || asDouble.truncateToDouble() != asDouble) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  if (asDouble.abs() > 9007199254740991) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be an int.',
      source: value,
    );
  }
  return asDouble.toInt();
}

Offset _parsePoint(Object? value, String field) {
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: field,
      message: '$field must be an object with x/y.',
    );
  }
  final map = _castMap(value);
  return Offset(_requireDouble(map, 'x'), _requireDouble(map, 'y'));
}

Color _parseColor(String value) {
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length == 6) {
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed == null) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'Invalid color: $value.',
        source: value,
      );
    }
    return Color(parsed);
  }
  if (normalized.length == 8) {
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        message: 'Invalid color: $value.',
        source: value,
      );
    }
    return Color(parsed);
  }
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    message: 'Invalid color: $value.',
    source: value,
  );
}

Color? _optionalColor(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  return _parseColor(value);
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
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: 'type',
        message: 'Unknown node type: $value.',
        source: value,
      );
  }
}

V2PathFillRule _parsePathFillRule(String value) {
  switch (value) {
    case 'nonZero':
      return V2PathFillRule.nonZero;
    case 'evenOdd':
      return V2PathFillRule.evenOdd;
    default:
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: 'fillRule',
        message: 'Unknown fillRule: $value.',
        source: value,
      );
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
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: 'align',
        message: 'Unknown text align: $value.',
        source: value,
      );
  }
}

PathFillRule _pathFillRuleFromV2(V2PathFillRule fillRule) {
  switch (fillRule) {
    case V2PathFillRule.nonZero:
      return PathFillRule.nonZero;
    case V2PathFillRule.evenOdd:
      return PathFillRule.evenOdd;
  }
}

V2PathFillRule _pathFillRuleToV2(PathFillRule fillRule) {
  switch (fillRule) {
    case PathFillRule.nonZero:
      return V2PathFillRule.nonZero;
    case PathFillRule.evenOdd:
      return V2PathFillRule.evenOdd;
  }
}
