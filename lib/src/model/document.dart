import 'dart:ui';

import '../core/grid_safety_limits.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../public/node_patch.dart';
import '../public/node_spec.dart';
import '../public/patch_field.dart';
import '../public/snapshot.dart' hide NodeId;
import 'scene_value_validation.dart';

typedef NodeLocatorEntry = ({int layerIndex, int nodeIndex});

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeById(
  Scene scene,
  NodeId id,
) {
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final node = layer.nodes[nodeIndex];
      if (node.id == id) {
        return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
      }
    }
  }
  return null;
}

Map<NodeId, NodeLocatorEntry> txnBuildNodeLocator(Scene scene) {
  final locator = <NodeId, NodeLocatorEntry>{};
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final node = layer.nodes[nodeIndex];
      locator[node.id] = (layerIndex: layerIndex, nodeIndex: nodeIndex);
    }
  }
  return locator;
}

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeByLocator({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required NodeId nodeId,
}) {
  final entry = nodeLocator[nodeId];
  if (entry == null) {
    return null;
  }
  final layerIndex = entry.layerIndex;
  if (layerIndex < 0 || layerIndex >= scene.layers.length) {
    return null;
  }
  final layer = scene.layers[layerIndex];
  final nodeIndex = entry.nodeIndex;
  if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
    return null;
  }
  final node = layer.nodes[nodeIndex];
  if (node.id != nodeId) {
    return null;
  }
  return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
}

SceneSnapshot txnSceneToSnapshot(Scene scene) {
  return SceneSnapshot(
    layers: scene.layers
        .map(
          (layer) => LayerSnapshot(
            isBackground: layer.isBackground,
            nodes: layer.nodes.map(txnNodeToSnapshot).toList(growable: false),
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

Scene txnSceneFromSnapshot(SceneSnapshot snapshot) {
  sceneValidateSnapshotValues(
    snapshot,
    onError: _txnSnapshotValidationError,
    requirePositiveGridCellSize: true,
  );
  final canonicalLayers = _txnCanonicalizeSnapshotLayers(snapshot.layers);
  return Scene(
    layers: canonicalLayers
        .map(
          (layer) => Layer(
            isBackground: layer.isBackground,
            nodes: layer.nodes.map(txnNodeFromSnapshot).toList(growable: false),
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

List<LayerSnapshot> _txnCanonicalizeSnapshotLayers(List<LayerSnapshot> layers) {
  var backgroundIndex = -1;
  for (var i = 0; i < layers.length; i++) {
    if (!layers[i].isBackground) continue;
    backgroundIndex = i;
    break;
  }

  if (backgroundIndex <= 0) {
    return layers;
  }

  final out = <LayerSnapshot>[layers[backgroundIndex]];
  for (var i = 0; i < layers.length; i++) {
    if (i == backgroundIndex) continue;
    out.add(layers[i]);
  }
  return out;
}

SceneNode txnNodeFromSnapshot(NodeSnapshot node) {
  switch (node) {
    case ImageNodeSnapshot image:
      return ImageNode(
        id: image.id,
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
      return TextNode(
        id: text.id,
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
    case StrokeNodeSnapshot stroke:
      return StrokeNode(
        id: stroke.id,
        points: stroke.points,
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
        svgPathData: path.svgPathData,
        fillColor: path.fillColor,
        strokeColor: path.strokeColor,
        strokeWidth: path.strokeWidth,
        fillRule: _txnPathFillRuleFromV2(path.fillRule),
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

NodeSnapshot txnNodeToSnapshot(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
      return ImageNodeSnapshot(
        id: image.id,
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
        points: stroke.points,
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
        svgPathData: path.svgPathData,
        fillColor: path.fillColor,
        strokeColor: path.strokeColor,
        strokeWidth: path.strokeWidth,
        fillRule: _txnPathFillRuleToV2(path.fillRule),
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

SceneNode txnNodeFromSpec(NodeSpec spec, {required NodeId fallbackId}) {
  sceneValidateNodeSpecValues(
    spec,
    field: 'spec',
    onError: _txnSnapshotValidationError,
  );
  final id = spec.id ?? fallbackId;
  switch (spec) {
    case ImageNodeSpec image:
      return ImageNode(
        id: id,
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
    case TextNodeSpec text:
      return TextNode(
        id: id,
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
    case StrokeNodeSpec stroke:
      return StrokeNode(
        id: id,
        points: stroke.points,
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
    case LineNodeSpec line:
      return LineNode(
        id: id,
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
    case RectNodeSpec rect:
      return RectNode(
        id: id,
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
    case PathNodeSpec path:
      return PathNode(
        id: id,
        svgPathData: path.svgPathData,
        fillColor: path.fillColor,
        strokeColor: path.strokeColor,
        strokeWidth: path.strokeWidth,
        fillRule: _txnPathFillRuleFromV2(path.fillRule),
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

bool txnApplyNodePatch(SceneNode node, NodePatch patch, {bool dryRun = false}) {
  var changed = false;

  if (node.id != patch.id) {
    throw ArgumentError.value(
      patch.id,
      'patch.id',
      'NodePatch id does not match target node id ${node.id}.',
    );
  }

  sceneValidateNodePatchValues(
    patch,
    field: 'patch',
    onError: _txnSnapshotValidationError,
  );

  changed = _txnApplyCommonPatch(node, patch.common, dryRun: dryRun) || changed;

  switch ((node, patch)) {
    case (ImageNode image, ImageNodePatch imagePatch):
      changed =
          _txnSet(imagePatch.imageId, image.imageId, (value) {
            image.imageId = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(imagePatch.size, image.size, (value) {
            image.size = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(imagePatch.naturalSize, image.naturalSize, (value) {
            image.naturalSize = value;
          }, dryRun: dryRun) ||
          changed;
    case (TextNode text, TextNodePatch textPatch):
      changed =
          _txnSet(textPatch.text, text.text, (value) {
            text.text = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(textPatch.size, text.size, (value) {
            text.size = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(textPatch.fontSize, text.fontSize, (value) {
            text.fontSize = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(textPatch.color, text.color, (value) {
            text.color = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(textPatch.align, text.align, (value) {
            text.align = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(textPatch.isBold, text.isBold, (value) {
            text.isBold = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(textPatch.isItalic, text.isItalic, (value) {
            text.isItalic = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(textPatch.isUnderline, text.isUnderline, (value) {
            text.isUnderline = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(textPatch.fontFamily, text.fontFamily, (value) {
            text.fontFamily = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(textPatch.maxWidth, text.maxWidth, (value) {
            text.maxWidth = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(textPatch.lineHeight, text.lineHeight, (value) {
            text.lineHeight = value;
          }, dryRun: dryRun) ||
          changed;
    case (StrokeNode stroke, StrokeNodePatch strokePatch):
      changed =
          _txnSetOffsets(strokePatch.points, stroke.points, (value) {
            stroke.points
              ..clear()
              ..addAll(value);
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(strokePatch.thickness, stroke.thickness, (value) {
            stroke.thickness = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(strokePatch.color, stroke.color, (value) {
            stroke.color = value;
          }, dryRun: dryRun) ||
          changed;
    case (LineNode line, LineNodePatch linePatch):
      changed =
          _txnSet(linePatch.start, line.start, (value) {
            line.start = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(linePatch.end, line.end, (value) {
            line.end = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(linePatch.thickness, line.thickness, (value) {
            line.thickness = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(linePatch.color, line.color, (value) {
            line.color = value;
          }, dryRun: dryRun) ||
          changed;
    case (RectNode rect, RectNodePatch rectPatch):
      changed =
          _txnSet(rectPatch.size, rect.size, (value) {
            rect.size = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(rectPatch.fillColor, rect.fillColor, (value) {
            rect.fillColor = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(rectPatch.strokeColor, rect.strokeColor, (value) {
            rect.strokeColor = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(rectPatch.strokeWidth, rect.strokeWidth, (value) {
            rect.strokeWidth = value;
          }, dryRun: dryRun) ||
          changed;
    case (PathNode path, PathNodePatch pathPatch):
      changed =
          _txnSet(pathPatch.svgPathData, path.svgPathData, (value) {
            path.svgPathData = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(pathPatch.fillColor, path.fillColor, (value) {
            path.fillColor = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSetNullable(pathPatch.strokeColor, path.strokeColor, (value) {
            path.strokeColor = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(pathPatch.strokeWidth, path.strokeWidth, (value) {
            path.strokeWidth = value;
          }, dryRun: dryRun) ||
          changed;
      changed =
          _txnSet(pathPatch.fillRule, _txnPathFillRuleToV2(path.fillRule), (
            value,
          ) {
            path.fillRule = _txnPathFillRuleFromV2(value);
          }, dryRun: dryRun) ||
          changed;
    default:
      throw ArgumentError(
        'Patch type ${patch.runtimeType} does not match node ${node.runtimeType}.',
      );
  }

  return changed;
}

bool txnInsertNodeInScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required SceneNode node,
  int? layerIndex,
}) {
  final targetLayerIndex = txnResolveInsertLayerIndex(
    scene: scene,
    layerIndex: layerIndex,
  );
  final targetLayer = scene.layers[targetLayerIndex];
  final insertedNodeIndex = targetLayer.nodes.length;
  targetLayer.nodes.add(node);
  nodeLocator[node.id] = (
    layerIndex: targetLayerIndex,
    nodeIndex: insertedNodeIndex,
  );
  return true;
}

SceneNode? txnEraseNodeFromScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required NodeId nodeId,
}) {
  final found = txnFindNodeByLocator(
    scene: scene,
    nodeLocator: nodeLocator,
    nodeId: nodeId,
  );
  if (found == null) {
    return null;
  }
  final layer = scene.layers[found.layerIndex];
  final removed = layer.nodes.removeAt(found.nodeIndex);
  nodeLocator.remove(nodeId);
  for (
    var nodeIndex = found.nodeIndex;
    nodeIndex < layer.nodes.length;
    nodeIndex++
  ) {
    final node = layer.nodes[nodeIndex];
    nodeLocator[node.id] = (layerIndex: found.layerIndex, nodeIndex: nodeIndex);
  }
  return removed;
}

int txnResolveInsertLayerIndex({required Scene scene, int? layerIndex}) {
  if (layerIndex != null) {
    if (layerIndex < 0 || layerIndex >= scene.layers.length) {
      throw RangeError.range(
        layerIndex,
        0,
        scene.layers.length - 1,
        'layerIndex',
      );
    }
    return layerIndex;
  }

  for (var i = 0; i < scene.layers.length; i++) {
    if (!scene.layers[i].isBackground) {
      return i;
    }
  }

  scene.layers.add(Layer());
  return scene.layers.length - 1;
}

Set<NodeId> txnNormalizeSelection({
  required Set<NodeId> rawSelection,
  required Scene scene,
}) {
  // Commit-time normalization keeps selection ids that still point to visible
  // non-background nodes. It intentionally does not enforce isSelectable to
  // preserve explicit selection flows like selectAll(onlySelectable: false).
  final normalizedCandidates = <NodeId>{
    for (final layer in scene.layers)
      for (final node in layer.nodes)
        if (!layer.isBackground && node.isVisible) node.id,
  };

  return <NodeId>{
    for (final id in rawSelection)
      if (normalizedCandidates.contains(id)) id,
  };
}

Set<NodeId> txnTranslateSelection({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Offset delta,
}) {
  if (delta == Offset.zero) {
    return const <NodeId>{};
  }

  final moved = <NodeId>{};
  for (final layer in scene.layers) {
    for (final node in layer.nodes) {
      if (!selectedNodeIds.contains(node.id)) continue;
      if (layer.isBackground) continue;
      if (node.isLocked || !node.isTransformable) continue;
      node.position = node.position + delta;
      moved.add(node.id);
    }
  }
  return moved;
}

bool txnNormalizeGrid(Scene scene) {
  final grid = scene.background.grid;
  if (grid.isEnabled && grid.cellSize < kMinGridCellSize) {
    grid.cellSize = kMinGridCellSize;
    return true;
  }
  return false;
}

PathFillRule _txnPathFillRuleFromV2(V2PathFillRule fillRule) {
  switch (fillRule) {
    case V2PathFillRule.nonZero:
      return PathFillRule.nonZero;
    case V2PathFillRule.evenOdd:
      return PathFillRule.evenOdd;
  }
}

V2PathFillRule _txnPathFillRuleToV2(PathFillRule fillRule) {
  switch (fillRule) {
    case PathFillRule.nonZero:
      return V2PathFillRule.nonZero;
    case PathFillRule.evenOdd:
      return V2PathFillRule.evenOdd;
  }
}

bool _txnApplyCommonPatch(
  SceneNode node,
  CommonNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.transform, node.transform, (value) {
        node.transform = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.opacity, node.opacity, (value) {
        node.opacity = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.hitPadding, node.hitPadding, (value) {
        node.hitPadding = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isVisible, node.isVisible, (value) {
        node.isVisible = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isSelectable, node.isSelectable, (value) {
        node.isSelectable = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isLocked, node.isLocked, (value) {
        node.isLocked = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isDeletable, node.isDeletable, (value) {
        node.isDeletable = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isTransformable, node.isTransformable, (value) {
        node.isTransformable = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnSet<T>(
  PatchField<T> patch,
  T current,
  void Function(T value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) return false;
  final next = patch.value;
  if (next == current) return false;
  if (!dryRun) {
    assign(next);
  }
  return true;
}

bool _txnSetNullable<T>(
  PatchField<T?> patch,
  T? current,
  void Function(T? value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) return false;

  final next = patch.isNullValue ? null : patch.value;
  if (next == current) return false;
  if (!dryRun) {
    assign(next);
  }
  return true;
}

bool _txnSetOffsets(
  PatchField<List<Offset>> patch,
  List<Offset> current,
  void Function(List<Offset> value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) return false;
  final next = List<Offset>.from(patch.value);
  if (_txnOffsetListsEqual(current, next)) return false;
  if (!dryRun) {
    assign(next);
  }
  return true;
}

bool _txnOffsetListsEqual(List<Offset> left, List<Offset> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

Never _txnSnapshotValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw ArgumentError.value(
    value,
    field,
    _txnCapitalizeValidationMessage(message),
  );
}

String _txnCapitalizeValidationMessage(String message) {
  if (message.isEmpty) return message;
  return '${message[0].toUpperCase()}${message.substring(1)}';
}
