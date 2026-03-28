import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import 'scene_node_boundary_mapping.dart';

SceneSnapshot sceneSnapshotFromScene(Scene scene) {
  final backgroundLayer = scene.backgroundLayer;
  return materializeSceneSnapshot(
    sceneSnapshotBackingFromValidated(
      backgroundLayer: backgroundLayer == null
          ? null
          : backgroundLayerSnapshotBackingFromValidated(
              nodes: backgroundLayer.nodes
                  .map(sceneNodeSnapshotBackingFromScene)
                  .toList(growable: false),
            ),
      layers: scene.layers
          .map(
            (layer) => contentLayerSnapshotBackingFromValidated(
              id: layer.id,
              nodes: layer.nodes
                  .map(sceneNodeSnapshotBackingFromScene)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      camera: cameraSnapshotBackingFromValidated(offset: scene.camera.offset),
      background: backgroundSnapshotBackingFromValidated(
        color: scene.background.color,
        grid: gridSnapshotBackingFromValidated(
          isEnabled: scene.background.grid.isEnabled,
          cellSize: scene.background.grid.cellSize,
          color: scene.background.grid.color,
        ),
      ),
      palette: scenePaletteSnapshotBackingFromValidated(
        penColors: scene.palette.penColors,
        backgroundColors: scene.palette.backgroundColors,
        gridSizes: scene.palette.gridSizes,
      ),
    ),
  );
}

NodeSnapshot sceneNodeSnapshotFromScene(SceneNode node) {
  return materializeNodeSnapshot(sceneNodeSnapshotBackingFromScene(node));
}

NodeSnapshotBacking sceneNodeSnapshotBackingFromScene(SceneNode node) {
  return sceneNodeSnapshotBackingFromViaBoundarySchema(node);
}
