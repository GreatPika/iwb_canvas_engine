import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../contract/snapshot.dart';
import 'scene_graph_traversal.dart';
import 'scene_node_boundary_mapping.dart';
import 'scene_policy.dart';

Scene sceneImportFromSnapshot(
  SceneSnapshot rawSnapshot, {
  int Function()? nextInstanceRevision,
}) {
  final canonicalSnapshot = ScenePolicy.validateImportSnapshot(rawSnapshot);
  return sceneFromSnapshot(
    canonicalSnapshot,
    nextInstanceRevision: nextInstanceRevision,
  );
}

Scene sceneFromSnapshot(
  SceneSnapshot snapshot, {
  int Function()? nextInstanceRevision,
}) {
  final instanceRevisionAllocator =
      nextInstanceRevision ?? createLocalRevisionAllocator();
  SceneNode mapNode(NodeSnapshot node) {
    return _sceneNodeFromSnapshot(
      node,
      nextInstanceRevision: instanceRevisionAllocator,
    );
  }

  return traverseSceneGraph<
    Scene,
    BackgroundLayerSnapshot,
    ContentLayerSnapshot,
    NodeSnapshot,
    SceneNode,
    BackgroundLayer,
    ContentLayer,
    Camera,
    Background,
    ScenePalette
  >(
    source: _snapshotSceneTraversalSource(snapshot),
    strategy: _sceneImportStrategy(snapshot, mapNode: mapNode),
  );
}

SceneNode _sceneNodeFromSnapshot(
  NodeSnapshot node, {
  required int Function() nextInstanceRevision,
}) {
  final instanceRevision = resolveSnapshotInstanceRevision(
    node.instanceRevision,
    nextInstanceRevision: nextInstanceRevision,
  );
  return sceneNodeFromSnapshotViaBoundarySchema(
    node,
    instanceRevision: instanceRevision,
    textSizePolicy: TextNodeSnapshotSizePolicy.recomputeFromLayout,
  );
}

SceneGraphTraversalSource<
  BackgroundLayerSnapshot,
  ContentLayerSnapshot,
  NodeSnapshot
>
_snapshotSceneTraversalSource(SceneSnapshot snapshot) {
  return SceneGraphTraversalSource(
    backgroundLayer: snapshot.backgroundLayer,
    layers: snapshot.layers,
    backgroundNodesOf: (layer) => layer.nodes,
    contentNodesOf: (layer) => layer.nodes,
  );
}

SceneGraphTraversalStrategy<
  Scene,
  BackgroundLayerSnapshot,
  ContentLayerSnapshot,
  NodeSnapshot,
  SceneNode,
  BackgroundLayer,
  ContentLayer,
  Camera,
  Background,
  ScenePalette
>
_sceneImportStrategy(
  SceneSnapshot snapshot, {
  required SceneNode Function(NodeSnapshot node) mapNode,
}) {
  return SceneGraphTraversalStrategy(
    mapNode: mapNode,
    buildBackgroundLayer: (_, nodes) => BackgroundLayer(nodes: nodes),
    buildContentLayer: (layer, nodes) =>
        ContentLayer(id: layer.id, nodes: nodes),
    buildCamera: () => Camera(offset: snapshot.camera.offset),
    buildBackground: () => Background(
      color: snapshot.background.color,
      grid: GridSettings(
        isEnabled: snapshot.background.grid.isEnabled,
        cellSize: snapshot.background.grid.cellSize,
        color: snapshot.background.grid.color,
      ),
    ),
    buildPalette: () => ScenePalette(
      penColors: snapshot.palette.penColors,
      backgroundColors: snapshot.palette.backgroundColors,
      gridSizes: snapshot.palette.gridSizes,
    ),
    buildResult:
        ({
          required backgroundLayer,
          required layers,
          required camera,
          required background,
          required palette,
        }) => Scene(
          backgroundLayer: backgroundLayer,
          layers: layers,
          camera: camera,
          background: background,
          palette: palette,
        ),
  );
}
