part of 'scene_builder.dart';

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
