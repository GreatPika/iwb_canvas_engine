import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/snapshot.dart';
import 'scene_node_boundary_mapping.dart';

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
  return sceneNodeSnapshotFromViaBoundarySchema(node);
}
