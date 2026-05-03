import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import 'scene_node_boundary_mapping_image.dart';
import 'scene_node_boundary_mapping_line.dart';
import 'scene_node_boundary_mapping_path.dart';
import 'scene_node_boundary_mapping_rect.dart';
import 'scene_node_boundary_mapping_stroke.dart';
import 'scene_node_boundary_mapping_text.dart';

SceneSnapshot projectValidatedSceneSnapshot(SceneSnapshotBacking backing) {
  return SceneSnapshot(
    backgroundLayer: BackgroundLayerSnapshot(
      nodes: backing.backgroundLayer.nodes
          .map(projectValidatedNodeSnapshot)
          .toList(growable: false),
    ),
    layers: backing.layers
        .map(
          (layer) => ContentLayerSnapshot(
            id: layer.id,
            nodes: layer.nodes
                .map(projectValidatedNodeSnapshot)
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
    camera: CameraSnapshot(offset: backing.camera.offset),
    background: BackgroundSnapshot(
      color: backing.background.color,
      grid: GridSnapshot(
        isEnabled: backing.background.grid.isEnabled,
        cellSize: backing.background.grid.cellSize,
        color: backing.background.grid.color,
      ),
    ),
    palette: ScenePaletteSnapshot(
      penColors: backing.palette.penColors,
      backgroundColors: backing.palette.backgroundColors,
      gridSizes: backing.palette.gridSizes,
    ),
  );
}

NodeSnapshot projectValidatedNodeSnapshot(NodeSnapshotBacking backing) {
  final common = nodeSnapshotCommonFieldsFromValidated(
    id: backing.id,
    instanceRevision: backing.instanceRevision,
    transform: backing.transform,
    opacity: backing.opacity,
    hitPadding: backing.hitPadding,
    isVisible: backing.isVisible,
    isSelectable: backing.isSelectable,
    isLocked: backing.isLocked,
    isDeletable: backing.isDeletable,
    isTransformable: backing.isTransformable,
  );
  return switch (backing) {
    ImageNodeSnapshotBacking image => imageNodeSnapshotFromValidated(
      common: common,
      fields: imageNodeSchemaFieldsFromBacking(image),
    ),
    TextNodeSnapshotBacking text => textNodeSnapshotFromValidated(
      common: common,
      fields: textNodeSchemaFieldsFromBacking(text),
    ),
    StrokeNodeSnapshotBacking stroke => strokeNodeSnapshotFromValidated(
      common: common,
      fields: strokeNodeSchemaFieldsFromBacking(stroke),
    ),
    LineNodeSnapshotBacking line => lineNodeSnapshotFromValidated(
      common: common,
      fields: lineNodeSchemaFieldsFromBacking(line),
    ),
    RectNodeSnapshotBacking rect => rectNodeSnapshotFromValidated(
      common: common,
      fields: rectNodeSchemaFieldsFromBacking(rect),
    ),
    PathNodeSnapshotBacking path => pathNodeSnapshotFromValidated(
      common: common,
      fields: pathNodeSchemaFieldsFromBacking(path),
    ),
  };
}
