import 'dart:ui';

import '../scene_defaults.dart';
import '../scene_structure_validation.dart';
import '../snapshot.dart';
import '../transform2d.dart';
import 'node_boundary_schema.dart';
import 'snapshot_boundary_impl.dart';
import 'snapshot_backing.dart';

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

SceneSnapshot materializeSceneSnapshot(SceneSnapshotBacking backing) {
  return materializeSceneSnapshotForInternalUse(backing);
}

SceneSnapshot sceneSnapshotFromValidatedBacking(SceneSnapshotBacking backing) {
  sceneValidateSceneSnapshotBackingStructure(backing);
  return materializeSceneSnapshot(backing);
}

BackgroundLayerSnapshot materializeBackgroundLayerSnapshot(
  BackgroundLayerSnapshotBacking backing,
) {
  return materializeBackgroundLayerSnapshotForInternalUse(backing);
}

List<ContentLayerSnapshot> materializeContentLayerSnapshotList(
  Iterable<ContentLayerSnapshotBacking> backings,
) {
  return List<ContentLayerSnapshot>.unmodifiable(
    backings.map(materializeContentLayerSnapshot),
  );
}

ContentLayerSnapshot materializeContentLayerSnapshot(
  ContentLayerSnapshotBacking backing,
) {
  return materializeContentLayerSnapshotForInternalUse(backing);
}

CameraSnapshot materializeCameraSnapshot(CameraSnapshotBacking backing) {
  return CameraSnapshot(offset: backing.offset);
}

BackgroundSnapshot materializeBackgroundSnapshot(
  BackgroundSnapshotBacking backing,
) {
  return BackgroundSnapshot(
    color: backing.color,
    grid: materializeGridSnapshot(backing.grid),
  );
}

GridSnapshot materializeGridSnapshot(GridSnapshotBacking backing) {
  return GridSnapshot(
    isEnabled: backing.isEnabled,
    cellSize: backing.cellSize,
    color: backing.color,
  );
}

ScenePaletteSnapshot materializeScenePaletteSnapshot(
  ScenePaletteSnapshotBacking backing,
) {
  return materializeScenePaletteSnapshotForInternalUse(backing);
}

List<NodeSnapshot> materializeNodeSnapshotList(
  Iterable<NodeSnapshotBacking> backings,
) {
  return List<NodeSnapshot>.unmodifiable(backings.map(materializeNodeSnapshot));
}

NodeSnapshot materializeNodeSnapshot(NodeSnapshotBacking backing) {
  return switch (backing) {
    ImageNodeSnapshotBacking image => materializeImageNodeSnapshot(image),
    TextNodeSnapshotBacking text => materializeTextNodeSnapshot(text),
    StrokeNodeSnapshotBacking stroke => materializeStrokeNodeSnapshot(stroke),
    LineNodeSnapshotBacking line => materializeLineNodeSnapshot(line),
    RectNodeSnapshotBacking rect => materializeRectNodeSnapshot(rect),
    PathNodeSnapshotBacking path => materializePathNodeSnapshot(path),
  };
}

ImageNodeSnapshot materializeImageNodeSnapshot(
  ImageNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as ImageNodeSnapshot;
}

TextNodeSnapshot materializeTextNodeSnapshot(TextNodeSnapshotBacking backing) {
  return materializeNodeSnapshotForInternalUse(backing) as TextNodeSnapshot;
}

StrokeNodeSnapshot materializeStrokeNodeSnapshot(
  StrokeNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as StrokeNodeSnapshot;
}

LineNodeSnapshot materializeLineNodeSnapshot(LineNodeSnapshotBacking backing) {
  return materializeNodeSnapshotForInternalUse(backing) as LineNodeSnapshot;
}

RectNodeSnapshot materializeRectNodeSnapshot(RectNodeSnapshotBacking backing) {
  return materializeNodeSnapshotForInternalUse(backing) as RectNodeSnapshot;
}

PathNodeSnapshot materializePathNodeSnapshot(PathNodeSnapshotBacking backing) {
  return materializeNodeSnapshotForInternalUse(backing) as PathNodeSnapshot;
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
  return sceneSnapshotFromValidatedBacking(backing);
}

BackgroundLayerSnapshot backgroundLayerSnapshotFromValidated({
  List<NodeSnapshot>? nodes,
}) {
  return materializeBackgroundLayerSnapshot(
    backgroundLayerSnapshotBackingFromValidated(
      nodes: nodes?.map(nodeSnapshotBackingOf).toList(growable: false),
    ),
  );
}

ContentLayerSnapshot contentLayerSnapshotFromValidated({
  required LayerId id,
  List<NodeSnapshot>? nodes,
}) {
  return materializeContentLayerSnapshot(
    contentLayerSnapshotBackingFromValidated(
      id: id,
      nodes: nodes?.map(nodeSnapshotBackingOf).toList(growable: false),
    ),
  );
}

CameraSnapshot cameraSnapshotFromValidated({Offset offset = Offset.zero}) {
  return materializeCameraSnapshot(
    cameraSnapshotBackingFromValidated(offset: offset),
  );
}

BackgroundSnapshot backgroundSnapshotFromValidated({
  Color color = SceneDefaults.backgroundColor,
  GridSnapshot grid = const GridSnapshot(),
}) {
  return materializeBackgroundSnapshot(
    backgroundSnapshotBackingFromValidated(
      color: color,
      grid: gridSnapshotBackingFromValidated(
        isEnabled: grid.isEnabled,
        cellSize: grid.cellSize,
        color: grid.color,
      ),
    ),
  );
}

GridSnapshot gridSnapshotFromValidated({
  bool isEnabled = false,
  double cellSize = SceneDefaults.gridCellSize,
  Color color = SceneDefaults.gridColor,
}) {
  return materializeGridSnapshot(
    gridSnapshotBackingFromValidated(
      isEnabled: isEnabled,
      cellSize: cellSize,
      color: color,
    ),
  );
}

ScenePaletteSnapshot scenePaletteSnapshotFromValidated({
  List<Color>? penColors,
  List<Color>? backgroundColors,
  List<double>? gridSizes,
}) {
  return materializeScenePaletteSnapshot(
    scenePaletteSnapshotBackingFromValidated(
      penColors: penColors,
      backgroundColors: backgroundColors,
      gridSizes: gridSizes,
    ),
  );
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
    materialize: materializeImageNodeSnapshot,
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
    materialize: materializeTextNodeSnapshot,
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
    materialize: materializeStrokeNodeSnapshot,
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
    materialize: materializeLineNodeSnapshot,
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
    materialize: materializeRectNodeSnapshot,
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
    materialize: materializePathNodeSnapshot,
  );
}
