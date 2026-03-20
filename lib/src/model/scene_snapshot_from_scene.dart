import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/snapshot.dart';

SceneSnapshot sceneSnapshotFromScene(Scene scene) {
  final backgroundLayer = scene.backgroundLayer;
  return sceneSnapshotFromValidated(
    backgroundLayer: backgroundLayer == null
        ? null
        : backgroundLayerSnapshotFromValidated(
            nodes: backgroundLayer.nodes
                .map(sceneNodeSnapshotFromScene)
                .toList(growable: false),
          ),
    layers: scene.layers
        .map(
          (layer) => contentLayerSnapshotFromValidated(
            id: layer.id,
            nodes: layer.nodes
                .map(sceneNodeSnapshotFromScene)
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
    camera: cameraSnapshotFromValidated(offset: scene.camera.offset),
    background: backgroundSnapshotFromValidated(
      color: scene.background.color,
      grid: gridSnapshotFromValidated(
        isEnabled: scene.background.grid.isEnabled,
        cellSize: scene.background.grid.cellSize,
        color: scene.background.grid.color,
      ),
    ),
    palette: scenePaletteSnapshotFromValidated(
      penColors: scene.palette.penColors,
      backgroundColors: scene.palette.backgroundColors,
      gridSizes: scene.palette.gridSizes,
    ),
  );
}

NodeSnapshot sceneNodeSnapshotFromScene(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      return _snapshotImageNode(node as ImageNode);
    case NodeType.text:
      return _snapshotTextNode(node as TextNode);
    case NodeType.stroke:
      return _snapshotStrokeNode(node as StrokeNode);
    case NodeType.line:
      return _snapshotLineNode(node as LineNode);
    case NodeType.rect:
      return _snapshotRectNode(node as RectNode);
    case NodeType.path:
      return _snapshotPathNode(node as PathNode);
  }
}

NodeSnapshot _snapshotImageNode(ImageNode image) {
  return imageNodeSnapshotFromValidated(
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
}

NodeSnapshot _snapshotTextNode(TextNode text) {
  return textNodeSnapshotFromValidated(
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
}

NodeSnapshot _snapshotStrokeNode(StrokeNode stroke) {
  return strokeNodeSnapshotFromValidated(
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
}

NodeSnapshot _snapshotLineNode(LineNode line) {
  return lineNodeSnapshotFromValidated(
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
}

NodeSnapshot _snapshotRectNode(RectNode rect) {
  return rectNodeSnapshotFromValidated(
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
}

NodeSnapshot _snapshotPathNode(PathNode path) {
  return pathNodeSnapshotFromValidated(
    id: path.id,
    instanceRevision: path.instanceRevision,
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
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
