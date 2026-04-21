import '../contract/internal/snapshot_fast_path.dart';
import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import 'scene_graph_traversal.dart';
import 'scene_import_draft.dart';
import 'scene_node_boundary_mapping.dart';
import 'scene_policy.dart';

Scene sceneImportFromDraft(
  SceneImportDraft rawDraft, {
  int Function()? nextInstanceRevision,
}) {
  final canonicalDraft = ScenePolicy.validateImportDraft(rawDraft);
  return sceneFromImportDraft(
    canonicalDraft,
    nextInstanceRevision: nextInstanceRevision,
  );
}

Scene sceneFromImportDraft(
  SceneImportDraft draft, {
  int Function()? nextInstanceRevision,
}) {
  final instanceRevisionAllocator =
      nextInstanceRevision ?? createLocalRevisionAllocator();
  SceneNode mapNode(NodeSnapshotBacking node) {
    return _sceneNodeFromImportDraftNode(
      node,
      nextInstanceRevision: instanceRevisionAllocator,
    );
  }

  return traverseSceneGraph<
    Scene,
    BackgroundLayerSnapshotBacking,
    ContentLayerSnapshotBacking,
    NodeSnapshotBacking,
    SceneNode,
    BackgroundLayer,
    ContentLayer,
    Camera,
    Background,
    ScenePalette
  >(
    source: _sceneImportDraftTraversalSource(draft),
    strategy: _sceneImportDraftStrategy(draft, mapNode: mapNode),
  );
}

SceneNode _sceneNodeFromImportDraftNode(
  NodeSnapshotBacking node, {
  required int Function() nextInstanceRevision,
}) {
  final instanceRevision = resolveSnapshotInstanceRevision(
    node.instanceRevision,
    nextInstanceRevision: nextInstanceRevision,
  );
  return sceneNodeFromSnapshotViaBoundarySchema(
    materializeNodeSnapshot(node),
    instanceRevision: instanceRevision,
  );
}

SceneGraphTraversalSource<
  BackgroundLayerSnapshotBacking,
  ContentLayerSnapshotBacking,
  NodeSnapshotBacking
>
_sceneImportDraftTraversalSource(SceneImportDraft draft) {
  return SceneGraphTraversalSource(
    backgroundLayer: draft.backgroundLayer,
    layers: draft.layers,
    backgroundNodesOf: (layer) => layer.nodes,
    contentNodesOf: (layer) => layer.nodes,
  );
}

SceneGraphTraversalStrategy<
  Scene,
  BackgroundLayerSnapshotBacking,
  ContentLayerSnapshotBacking,
  NodeSnapshotBacking,
  SceneNode,
  BackgroundLayer,
  ContentLayer,
  Camera,
  Background,
  ScenePalette
>
_sceneImportDraftStrategy(
  SceneImportDraft draft, {
  required SceneNode Function(NodeSnapshotBacking node) mapNode,
}) {
  return SceneGraphTraversalStrategy(
    mapNode: mapNode,
    buildBackgroundLayer: (_, nodes) => BackgroundLayer(nodes: nodes),
    buildContentLayer: (layer, nodes) =>
        ContentLayer(id: layer.id, nodes: nodes),
    buildCamera: () => Camera(offset: draft.camera.offset),
    buildBackground: () => Background(
      color: draft.background.color,
      grid: GridSettings(
        isEnabled: draft.background.grid.isEnabled,
        cellSize: draft.background.grid.cellSize,
        color: draft.background.grid.color,
      ),
    ),
    buildPalette: () => ScenePalette(
      penColors: draft.palette.penColors,
      backgroundColors: draft.palette.backgroundColors,
      gridSizes: draft.palette.gridSizes,
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
