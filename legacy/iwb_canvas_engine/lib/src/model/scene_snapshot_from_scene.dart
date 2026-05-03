import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import 'scene_graph_traversal.dart';
import 'scene_node_boundary_mapping.dart';
import 'scene_snapshot_projection.dart';

SceneSnapshot sceneSnapshotFromScene(Scene scene) {
  return traverseSceneGraph<
    SceneSnapshot,
    BackgroundLayer,
    ContentLayer,
    SceneNode,
    NodeSnapshotBacking,
    BackgroundLayerSnapshotBacking,
    ContentLayerSnapshotBacking,
    CameraSnapshotBacking,
    BackgroundSnapshotBacking,
    ScenePaletteSnapshotBacking
  >(
    source: _runtimeSceneTraversalSource(scene),
    strategy: _sceneExportStrategy(scene),
  );
}

NodeSnapshot sceneNodeSnapshotFromScene(SceneNode node) {
  return projectValidatedNodeSnapshot(sceneNodeSnapshotBackingFromScene(node));
}

NodeSnapshotBacking sceneNodeSnapshotBackingFromScene(SceneNode node) {
  return sceneNodeSnapshotBackingFromViaBoundarySchema(node);
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
  SceneSnapshot,
  BackgroundLayer,
  ContentLayer,
  SceneNode,
  NodeSnapshotBacking,
  BackgroundLayerSnapshotBacking,
  ContentLayerSnapshotBacking,
  CameraSnapshotBacking,
  BackgroundSnapshotBacking,
  ScenePaletteSnapshotBacking
>
_sceneExportStrategy(Scene scene) {
  return SceneGraphTraversalStrategy(
    mapNode: sceneNodeSnapshotBackingFromScene,
    buildBackgroundLayer: (_, nodes) =>
        backgroundLayerSnapshotBackingFromValidated(nodes: nodes),
    buildContentLayer: (layer, nodes) =>
        contentLayerSnapshotBackingFromValidated(id: layer.id, nodes: nodes),
    buildCamera: () =>
        cameraSnapshotBackingFromValidated(offset: scene.camera.offset),
    buildBackground: () => backgroundSnapshotBackingFromValidated(
      color: scene.background.color,
      grid: gridSnapshotBackingFromValidated(
        isEnabled: scene.background.grid.isEnabled,
        cellSize: scene.background.grid.cellSize,
        color: scene.background.grid.color,
      ),
    ),
    buildPalette: () => scenePaletteSnapshotBackingFromValidated(
      penColors: scene.palette.penColors,
      backgroundColors: scene.palette.backgroundColors,
      gridSizes: scene.palette.gridSizes,
    ),
    buildResult:
        ({
          required backgroundLayer,
          required layers,
          required camera,
          required background,
          required palette,
        }) {
          final backing = sceneSnapshotBackingFromValidated(
            backgroundLayer: backgroundLayer,
            layers: layers,
            camera: camera,
            background: background,
            palette: palette,
          );
          return projectValidatedSceneSnapshot(backing);
        },
  );
}
