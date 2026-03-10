part of 'scene_builder.dart';

SceneSnapshot _snapshotFromScene(Scene scene) {
  final backgroundLayer = scene.backgroundLayer;
  return sceneSnapshotFromValidated(
    backgroundLayer: backgroundLayer == null
        ? null
        : backgroundLayerSnapshotFromValidated(
            nodes: backgroundLayer.nodes
                .map(_snapshotNodeFromScene)
                .toList(growable: false),
          ),
    layers: scene.layers
        .map(
          (layer) => contentLayerSnapshotFromValidated(
            id: layer.id,
            nodes: layer.nodes
                .map(_snapshotNodeFromScene)
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

NodeSnapshot _snapshotNodeFromScene(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
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
    case NodeType.text:
      final text = node as TextNode;
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
    case NodeType.stroke:
      final stroke = node as StrokeNode;
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
    case NodeType.line:
      final line = node as LineNode;
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
    case NodeType.rect:
      final rect = node as RectNode;
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
    case NodeType.path:
      final path = node as PathNode;
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
}
