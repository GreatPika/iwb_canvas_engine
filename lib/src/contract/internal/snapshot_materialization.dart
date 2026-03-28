import 'dart:ui';

import '../scene_defaults.dart';
import '../snapshot.dart';
import '../transform2d.dart';
import 'node_boundary_schema.dart';
import 'snapshot_backing.dart';

SceneSnapshot materializeSceneSnapshot(SceneSnapshotBacking backing) {
  return SceneSnapshot.materialize(backing);
}

BackgroundLayerSnapshot materializeBackgroundLayerSnapshot(
  BackgroundLayerSnapshotBacking backing,
) {
  return BackgroundLayerSnapshot.materialize(backing);
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
  return ContentLayerSnapshot.materialize(backing);
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
  return ScenePaletteSnapshot.materialize(backing);
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
  return ImageNodeSnapshot.materialize(backing);
}

TextNodeSnapshot materializeTextNodeSnapshot(TextNodeSnapshotBacking backing) {
  return TextNodeSnapshot.materialize(backing);
}

StrokeNodeSnapshot materializeStrokeNodeSnapshot(
  StrokeNodeSnapshotBacking backing,
) {
  return StrokeNodeSnapshot.materialize(backing);
}

LineNodeSnapshot materializeLineNodeSnapshot(LineNodeSnapshotBacking backing) {
  return LineNodeSnapshot.materialize(backing);
}

RectNodeSnapshot materializeRectNodeSnapshot(RectNodeSnapshotBacking backing) {
  return RectNodeSnapshot.materialize(backing);
}

PathNodeSnapshot materializePathNodeSnapshot(PathNodeSnapshotBacking backing) {
  return PathNodeSnapshot.materialize(backing);
}

SceneSnapshot sceneSnapshotFromValidated({
  List<ContentLayerSnapshot>? layers,
  BackgroundLayerSnapshot? backgroundLayer,
  CameraSnapshot? camera,
  BackgroundSnapshot? background,
  ScenePaletteSnapshot? palette,
}) {
  return materializeSceneSnapshot(
    sceneSnapshotBackingFromValidated(
      layers: layers
          ?.map((layer) => layer.internalBacking)
          .toList(growable: false),
      backgroundLayer: backgroundLayer?.internalBacking,
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
      palette: palette?.internalBacking,
    ),
  );
}

BackgroundLayerSnapshot backgroundLayerSnapshotFromValidated({
  List<NodeSnapshot>? nodes,
}) {
  return materializeBackgroundLayerSnapshot(
    backgroundLayerSnapshotBackingFromValidated(
      nodes: nodes?.map((node) => node.internalBacking).toList(growable: false),
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
      nodes: nodes?.map((node) => node.internalBacking).toList(growable: false),
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

ImageNodeSnapshot imageNodeSnapshotFromValidated({
  required NodeId id,
  int instanceRevision = 0,
  required String imageId,
  required Size size,
  Size? naturalSize,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  return materializeImageNodeSnapshot(
    imageNodeSnapshotBackingFromValidated(
      common: snapshotCommonSchemaFieldsFromValidated((
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
      )),
      fields: imageNodeSchemaFieldsFromValidated((
        imageId: imageId,
        size: size,
        naturalSize: naturalSize,
      )),
    ),
  );
}

TextNodeSnapshot textNodeSnapshotFromValidated({
  required NodeId id,
  int instanceRevision = 0,
  required String text,
  required Size size,
  double fontSize = 24,
  required Color color,
  TextAlign align = TextAlign.left,
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  return materializeTextNodeSnapshot(
    textNodeSnapshotBackingFromValidated(
      common: snapshotCommonSchemaFieldsFromValidated((
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
      )),
      fields: textNodeSnapshotSchemaFieldsFromValidated((
        text: text,
        size: size,
        fontSize: fontSize,
        color: color,
        align: align,
        isBold: isBold,
        isItalic: isItalic,
        isUnderline: isUnderline,
        fontFamily: fontFamily,
        maxWidth: maxWidth,
        lineHeight: lineHeight,
      )),
    ),
  );
}

StrokeNodeSnapshot strokeNodeSnapshotFromValidated({
  required NodeId id,
  int instanceRevision = 0,
  required List<Offset> points,
  int pointsRevision = 0,
  required double thickness,
  required Color color,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  return materializeStrokeNodeSnapshot(
    strokeNodeSnapshotBackingFromValidated(
      common: snapshotCommonSchemaFieldsFromValidated((
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
      )),
      fields: strokeNodeSnapshotSchemaFieldsFromValidated((
        points: points,
        pointsRevision: pointsRevision,
        thickness: thickness,
        color: color,
      )),
    ),
  );
}

LineNodeSnapshot lineNodeSnapshotFromValidated({
  required NodeId id,
  int instanceRevision = 0,
  required Offset start,
  required Offset end,
  required double thickness,
  required Color color,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  return materializeLineNodeSnapshot(
    lineNodeSnapshotBackingFromValidated(
      common: snapshotCommonSchemaFieldsFromValidated((
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
      )),
      fields: lineNodeSchemaFieldsFromValidated((
        start: start,
        end: end,
        thickness: thickness,
        color: color,
      )),
    ),
  );
}

RectNodeSnapshot rectNodeSnapshotFromValidated({
  required NodeId id,
  int instanceRevision = 0,
  required Size size,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth = 0,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  return materializeRectNodeSnapshot(
    rectNodeSnapshotBackingFromValidated(
      common: snapshotCommonSchemaFieldsFromValidated((
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
      )),
      fields: rectNodeSchemaFieldsFromValidated((
        size: size,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
      )),
    ),
  );
}

PathNodeSnapshot pathNodeSnapshotFromValidated({
  required NodeId id,
  int instanceRevision = 0,
  required String svgPathData,
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth = 0,
  PathFillRule fillRule = PathFillRule.nonZero,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
}) {
  return materializePathNodeSnapshot(
    pathNodeSnapshotBackingFromValidated(
      common: snapshotCommonSchemaFieldsFromValidated((
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
      )),
      fields: pathNodeSchemaFieldsFromValidated((
        svgPathData: svgPathData,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        fillRule: fillRule,
      )),
    ),
  );
}
