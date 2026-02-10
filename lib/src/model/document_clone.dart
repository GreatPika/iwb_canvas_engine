import 'dart:ui';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/transform2d.dart';

Scene txnCloneScene(Scene scene) {
  return Scene(
    layers: scene.layers.map(txnCloneLayer).toList(growable: false),
    camera: Camera(offset: scene.camera.offset),
    background: Background(
      color: scene.background.color,
      grid: GridSettings(
        isEnabled: scene.background.grid.isEnabled,
        cellSize: scene.background.grid.cellSize,
        color: scene.background.grid.color,
      ),
    ),
    palette: ScenePalette(
      penColors: List<Color>.from(scene.palette.penColors),
      backgroundColors: List<Color>.from(scene.palette.backgroundColors),
      gridSizes: List<double>.from(scene.palette.gridSizes),
    ),
  );
}

Layer txnCloneLayer(Layer layer) {
  return Layer(
    nodes: layer.nodes.map(txnCloneNode).toList(growable: false),
    isBackground: layer.isBackground,
  );
}

SceneNode txnCloneNode(SceneNode node) {
  final transform = _txnCloneTransform(node.transform);

  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
      return ImageNode(
        id: image.id,
        imageId: image.imageId,
        size: image.size,
        naturalSize: image.naturalSize,
        transform: transform,
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
        transform: transform,
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
      return StrokeNode(
        id: stroke.id,
        points: List<Offset>.from(stroke.points),
        thickness: stroke.thickness,
        color: stroke.color,
        transform: transform,
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
      return LineNode(
        id: line.id,
        start: line.start,
        end: line.end,
        thickness: line.thickness,
        color: line.color,
        transform: transform,
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
      return RectNode(
        id: rect.id,
        size: rect.size,
        fillColor: rect.fillColor,
        strokeColor: rect.strokeColor,
        strokeWidth: rect.strokeWidth,
        transform: transform,
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
      return PathNode(
        id: path.id,
        svgPathData: path.svgPathData,
        fillColor: path.fillColor,
        strokeColor: path.strokeColor,
        strokeWidth: path.strokeWidth,
        fillRule: path.fillRule,
        transform: transform,
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

Transform2D _txnCloneTransform(Transform2D transform) {
  return Transform2D(
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    tx: transform.tx,
    ty: transform.ty,
  );
}

Set<NodeId> txnCollectNodeIds(Scene scene) {
  return <NodeId>{
    for (final layer in scene.layers)
      for (final node in layer.nodes) node.id,
  };
}

int txnInitialNodeIdSeed(Scene scene) {
  var maxId = -1;
  for (final layer in scene.layers) {
    for (final node in layer.nodes) {
      final id = node.id;
      if (!id.startsWith('node-')) continue;
      final parsed = int.tryParse(id.substring('node-'.length));
      if (parsed == null || parsed < 0) continue;
      if (parsed > maxId) {
        maxId = parsed;
      }
    }
  }
  return maxId + 1;
}
