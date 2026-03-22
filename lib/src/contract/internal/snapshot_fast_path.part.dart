part of '../snapshot.dart';

@internal
SceneSnapshot sceneSnapshotFromValidated({
  List<ContentLayerSnapshot>? layers,
  BackgroundLayerSnapshot? backgroundLayer,
  CameraSnapshot? camera,
  BackgroundSnapshot? background,
  ScenePaletteSnapshot? palette,
}) {
  return SceneSnapshot._internal(
    layers: layers,
    backgroundLayer: backgroundLayer,
    camera: camera,
    background: background,
    palette: palette,
  );
}

@internal
BackgroundLayerSnapshot backgroundLayerSnapshotFromValidated({
  List<NodeSnapshot>? nodes,
}) {
  return BackgroundLayerSnapshot._internal(nodes: nodes);
}

@internal
ContentLayerSnapshot contentLayerSnapshotFromValidated({
  required LayerId id,
  List<NodeSnapshot>? nodes,
}) {
  return ContentLayerSnapshot._internal(id: id, nodes: nodes);
}

@internal
CameraSnapshot cameraSnapshotFromValidated({Offset offset = Offset.zero}) {
  return CameraSnapshot(offset: offset);
}

@internal
BackgroundSnapshot backgroundSnapshotFromValidated({
  Color color = SceneDefaults.backgroundColor,
  GridSnapshot grid = const GridSnapshot(),
}) {
  return BackgroundSnapshot(color: color, grid: grid);
}

@internal
GridSnapshot gridSnapshotFromValidated({
  bool isEnabled = false,
  double cellSize = SceneDefaults.gridCellSize,
  Color color = SceneDefaults.gridColor,
}) {
  return GridSnapshot(isEnabled: isEnabled, cellSize: cellSize, color: color);
}

@internal
ScenePaletteSnapshot scenePaletteSnapshotFromValidated({
  List<Color>? penColors,
  List<Color>? backgroundColors,
  List<double>? gridSizes,
}) {
  return ScenePaletteSnapshot._internal(
    penColors: penColors,
    backgroundColors: backgroundColors,
    gridSizes: gridSizes,
  );
}

@internal
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
  return ImageNodeSnapshot._internal(
    id: id,
    instanceRevision: instanceRevision,
    imageId: imageId,
    size: size,
    naturalSize: naturalSize,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

@internal
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
  return TextNodeSnapshot._internal(
    id: id,
    instanceRevision: instanceRevision,
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
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

@internal
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
  return StrokeNodeSnapshot._internal(
    id: id,
    instanceRevision: instanceRevision,
    points: points,
    pointsRevision: pointsRevision,
    thickness: thickness,
    color: color,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

@internal
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
  return LineNodeSnapshot._internal(
    id: id,
    instanceRevision: instanceRevision,
    start: start,
    end: end,
    thickness: thickness,
    color: color,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

@internal
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
  return RectNodeSnapshot._internal(
    id: id,
    instanceRevision: instanceRevision,
    size: size,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

@internal
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
  return PathNodeSnapshot._internal(
    id: id,
    instanceRevision: instanceRevision,
    svgPathData: svgPathData,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    fillRule: fillRule,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}
