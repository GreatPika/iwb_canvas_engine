import 'dart:ui';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/ids.dart' show LayerId;
import 'scene_node_boundary_mapping.dart';

Scene txnCloneSceneShallow(Scene scene) {
  return Scene(
    layers: scene.layers,
    backgroundLayer: scene.backgroundLayer,
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

Scene txnCloneScene(Scene scene) {
  final backgroundLayer = scene.backgroundLayer;
  return Scene(
    layers: scene.layers.map(txnCloneContentLayer).toList(growable: false),
    backgroundLayer: backgroundLayer == null
        ? null
        : txnCloneBackgroundLayer(backgroundLayer),
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

BackgroundLayer txnCloneBackgroundLayerShallow(BackgroundLayer layer) {
  return BackgroundLayer(nodes: layer.nodes);
}

BackgroundLayer txnCloneBackgroundLayer(BackgroundLayer layer) {
  return BackgroundLayer(
    nodes: layer.nodes.map(txnCloneNode).toList(growable: false),
  );
}

ContentLayer txnCloneContentLayerShallow(ContentLayer layer) {
  return ContentLayer(id: layer.id, nodes: layer.nodes);
}

ContentLayer txnCloneContentLayer(ContentLayer layer) {
  return ContentLayer(
    id: layer.id,
    nodes: layer.nodes.map(txnCloneNode).toList(growable: false),
  );
}

SceneNode txnCloneNode(SceneNode node) {
  return cloneSceneNodeViaBoundarySchema(node);
}

Set<NodeId> txnCollectNodeIds(Scene scene) {
  final backgroundLayer = scene.backgroundLayer;
  return <NodeId>{
    if (backgroundLayer != null)
      for (final node in backgroundLayer.nodes) node.id,
    for (final layer in scene.layers)
      for (final node in layer.nodes) node.id,
  };
}

Set<LayerId> txnCollectLayerIds(Scene scene) {
  return <LayerId>{for (final layer in scene.layers) layer.id};
}
