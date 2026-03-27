import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../contract/snapshot.dart';
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
  return Scene(
    backgroundLayer: BackgroundLayer(
      nodes: snapshot.backgroundLayer.nodes
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
            id: layer.id,
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
