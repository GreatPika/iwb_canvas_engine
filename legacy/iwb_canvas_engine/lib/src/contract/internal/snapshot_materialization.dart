import 'dart:ui';

import '../scene_defaults.dart';
import '../snapshot.dart';
import '../transform2d.dart';
import 'node_boundary_schema.dart';
import 'snapshot_backing.dart';
import 'snapshot_boundary_impl.dart';

typedef _SnapshotNodeBackingBuilder<
  TBacking extends NodeSnapshotBacking,
  TFields
> =
    TBacking Function({
      required NodeSnapshotCommonSchemaFields common,
      required TFields fields,
    });

typedef _SnapshotNodeMaterializer<
  TSnapshot extends NodeSnapshot,
  TBacking extends NodeSnapshotBacking
> = TSnapshot Function(TBacking backing);

ImageNodeSnapshot _materializeImageNodeSnapshotFromValidated(
  ImageNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as ImageNodeSnapshot;
}

TextNodeSnapshot _materializeTextNodeSnapshotFromValidated(
  TextNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as TextNodeSnapshot;
}

StrokeNodeSnapshot _materializeStrokeNodeSnapshotFromValidated(
  StrokeNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as StrokeNodeSnapshot;
}

LineNodeSnapshot _materializeLineNodeSnapshotFromValidated(
  LineNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as LineNodeSnapshot;
}

RectNodeSnapshot _materializeRectNodeSnapshotFromValidated(
  RectNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as RectNodeSnapshot;
}

PathNodeSnapshot _materializePathNodeSnapshotFromValidated(
  PathNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as PathNodeSnapshot;
}

BackgroundLayerSnapshot backgroundLayerSnapshotFromValidated({
  List<NodeSnapshot>? nodes,
}) {
  return materializeBackgroundLayerSnapshotForInternalUse(
    backgroundLayerSnapshotBackingFromValidated(
      nodes: nodes?.map(nodeSnapshotBackingOf).toList(growable: false),
    ),
  );
}

ContentLayerSnapshot contentLayerSnapshotFromValidated({
  required LayerId id,
  List<NodeSnapshot>? nodes,
}) {
  return materializeContentLayerSnapshotForInternalUse(
    contentLayerSnapshotBackingFromValidated(
      id: id,
      nodes: nodes?.map(nodeSnapshotBackingOf).toList(growable: false),
    ),
  );
}

CameraSnapshot cameraSnapshotFromValidated({Offset offset = Offset.zero}) {
  final backing = cameraSnapshotBackingFromValidated(offset: offset);
  return CameraSnapshot(offset: backing.offset);
}

BackgroundSnapshot backgroundSnapshotFromValidated({
  Color color = SceneDefaults.backgroundColor,
  GridSnapshot? grid,
}) {
  final resolvedGrid = grid ?? GridSnapshot();
  final backing = backgroundSnapshotBackingFromValidated(
    color: color,
    grid: gridSnapshotBackingFromValidated(
      isEnabled: resolvedGrid.isEnabled,
      cellSize: resolvedGrid.cellSize,
      color: resolvedGrid.color,
    ),
  );
  return BackgroundSnapshot(
    color: backing.color,
    grid: GridSnapshot(
      isEnabled: backing.grid.isEnabled,
      cellSize: backing.grid.cellSize,
      color: backing.grid.color,
    ),
  );
}

GridSnapshot gridSnapshotFromValidated({
  bool isEnabled = false,
  double cellSize = SceneDefaults.gridCellSize,
  Color color = SceneDefaults.gridColor,
}) {
  final backing = gridSnapshotBackingFromValidated(
    isEnabled: isEnabled,
    cellSize: cellSize,
    color: color,
  );
  return GridSnapshot(
    isEnabled: backing.isEnabled,
    cellSize: backing.cellSize,
    color: backing.color,
  );
}

ScenePaletteSnapshot scenePaletteSnapshotFromValidated({
  List<Color>? penColors,
  List<Color>? backgroundColors,
  List<double>? gridSizes,
}) {
  final backing = scenePaletteSnapshotBackingFromValidated(
    penColors: penColors,
    backgroundColors: backgroundColors,
    gridSizes: gridSizes,
  );
  return ScenePaletteSnapshot(
    penColors: backing.penColors,
    backgroundColors: backing.backgroundColors,
    gridSizes: backing.gridSizes,
  );
}

SceneSnapshot sceneSnapshotFromValidated({
  List<ContentLayerSnapshot>? layers,
  BackgroundLayerSnapshot? backgroundLayer,
  CameraSnapshot? camera,
  BackgroundSnapshot? background,
  ScenePaletteSnapshot? palette,
}) {
  final backing = sceneSnapshotBackingFromValidated(
    layers: layers?.map(contentLayerSnapshotBackingOf).toList(growable: false),
    backgroundLayer: backgroundLayer == null
        ? null
        : backgroundLayerSnapshotBackingOf(backgroundLayer),
    camera: camera == null
        ? null
        : cameraSnapshotBackingFromValidated(offset: camera.offset),
    background: background == null
        ? null
        : backgroundSnapshotBackingFromValidated(
            color: background.color,
            grid: gridSnapshotBackingFromValidated(
              isEnabled: background.grid.isEnabled,
              cellSize: background.grid.cellSize,
              color: background.grid.color,
            ),
          ),
    palette: palette == null ? null : scenePaletteSnapshotBackingOf(palette),
  );
  validateSceneSnapshotBackingMetadataValues(backing);
  return materializeSceneSnapshotForInternalUse(backing);
}

NodeSnapshotCommonSchemaFields nodeSnapshotCommonFieldsFromValidated({
  required NodeId id,
  int instanceRevision = 0,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  return snapshotCommonSchemaFieldsFromValidated((
    id: id,
    instanceRevision: instanceRevision,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  ));
}

TSnapshot _nodeSnapshotFromValidated<
  TSnapshot extends NodeSnapshot,
  TBacking extends NodeSnapshotBacking,
  TFields
>({
  required NodeSnapshotCommonSchemaFields common,
  required TFields fields,
  required _SnapshotNodeBackingBuilder<TBacking, TFields> buildBacking,
  required _SnapshotNodeMaterializer<TSnapshot, TBacking> materialize,
}) {
  return materialize(buildBacking(common: common, fields: fields));
}

ImageNodeSnapshot imageNodeSnapshotFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required ImageNodeSchemaFields fields,
}) {
  return _nodeSnapshotFromValidated(
    common: common,
    fields: imageNodeSchemaFieldsFromValidated(fields),
    buildBacking: imageNodeSnapshotBackingFromValidated,
    materialize: _materializeImageNodeSnapshotFromValidated,
  );
}

TextNodeSnapshot textNodeSnapshotFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required TextNodeSnapshotSchemaFields fields,
}) {
  return _nodeSnapshotFromValidated(
    common: common,
    fields: textNodeSnapshotSchemaFieldsFromValidated(fields),
    buildBacking: textNodeSnapshotBackingFromValidated,
    materialize: _materializeTextNodeSnapshotFromValidated,
  );
}

StrokeNodeSnapshot strokeNodeSnapshotFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required StrokeNodeSnapshotSchemaInput fields,
}) {
  return _nodeSnapshotFromValidated(
    common: common,
    fields: strokeNodeSnapshotSchemaFieldsFromValidated(fields),
    buildBacking: strokeNodeSnapshotBackingFromValidated,
    materialize: _materializeStrokeNodeSnapshotFromValidated,
  );
}

LineNodeSnapshot lineNodeSnapshotFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required LineNodeSchemaFields fields,
}) {
  return _nodeSnapshotFromValidated(
    common: common,
    fields: lineNodeSchemaFieldsFromValidated(fields),
    buildBacking: lineNodeSnapshotBackingFromValidated,
    materialize: _materializeLineNodeSnapshotFromValidated,
  );
}

RectNodeSnapshot rectNodeSnapshotFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return _nodeSnapshotFromValidated(
    common: common,
    fields: rectNodeSchemaFieldsFromValidated(fields),
    buildBacking: rectNodeSnapshotBackingFromValidated,
    materialize: _materializeRectNodeSnapshotFromValidated,
  );
}

PathNodeSnapshot pathNodeSnapshotFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return _nodeSnapshotFromValidated(
    common: common,
    fields: pathNodeSchemaFieldsFromValidated(fields),
    buildBacking: pathNodeSnapshotBackingFromValidated,
    materialize: _materializePathNodeSnapshotFromValidated,
  );
}
