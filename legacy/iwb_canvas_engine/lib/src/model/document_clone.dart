import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/ids.dart' show LayerId;
import 'scene_graph_traversal.dart';
import 'scene_node_boundary_mapping.dart';

Scene txnCloneSceneShallow(Scene scene) {
  return Scene(
    layers: List<ContentLayer>.from(scene.layers),
    backgroundLayer: scene.backgroundLayer,
    camera: Camera(offset: scene.camera.offset),
    background: _cloneBackground(scene.background),
    palette: _clonePalette(scene.palette),
  );
}

Scene txnCloneScene(Scene scene) => _cloneScene(scene, mapNode: txnCloneNode);

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
  return cloneRuntimeSceneNode(node);
}

Scene _cloneScene(
  Scene scene, {
  required SceneNode Function(SceneNode node) mapNode,
}) {
  return traverseSceneGraph<
    Scene,
    BackgroundLayer,
    ContentLayer,
    SceneNode,
    SceneNode,
    BackgroundLayer,
    ContentLayer,
    Camera,
    Background,
    ScenePalette
  >(
    source: _runtimeSceneTraversalSource(scene),
    strategy: _cloneSceneStrategy(scene, mapNode: mapNode),
  );
}

SceneGraphTraversalSource<BackgroundLayer, ContentLayer, SceneNode>
_runtimeSceneTraversalSource(Scene scene) {
  return SceneGraphTraversalSource(
    backgroundLayer: scene.backgroundLayer,
    layers: scene.layers,
    backgroundNodesOf: (layer) => layer.nodes,
    contentNodesOf: (layer) => layer.nodes,
  );
}

SceneGraphTraversalStrategy<
  Scene,
  BackgroundLayer,
  ContentLayer,
  SceneNode,
  SceneNode,
  BackgroundLayer,
  ContentLayer,
  Camera,
  Background,
  ScenePalette
>
_cloneSceneStrategy(
  Scene scene, {
  required SceneNode Function(SceneNode node) mapNode,
}) {
  return SceneGraphTraversalStrategy(
    mapNode: mapNode,
    buildBackgroundLayer: (_, nodes) => BackgroundLayer(nodes: nodes),
    buildContentLayer: (layer, nodes) =>
        ContentLayer(id: layer.id, nodes: nodes),
    buildCamera: () => Camera(offset: scene.camera.offset),
    buildBackground: () => _cloneBackground(scene.background),
    buildPalette: () => _clonePalette(scene.palette),
    buildResult:
        ({
          required backgroundLayer,
          required layers,
          required camera,
          required background,
          required palette,
        }) => Scene(
          layers: layers,
          backgroundLayer: backgroundLayer,
          camera: camera,
          background: background,
          palette: palette,
        ),
  );
}

Background _cloneBackground(Background background) {
  return Background(
    color: background.color,
    grid: GridSettings(
      isEnabled: background.grid.isEnabled,
      cellSize: background.grid.cellSize,
      color: background.grid.color,
    ),
  );
}

ScenePalette _clonePalette(ScenePalette palette) {
  return ScenePalette(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
  );
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
