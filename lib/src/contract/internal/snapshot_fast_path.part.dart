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
  final common = NodeBoundarySchema.snapshotCommonFromValidated((
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
  final fields = NodeBoundarySchema.imageFieldsFromValidated((
    imageId: imageId,
    size: size,
    naturalSize: naturalSize,
  ));
  return _imageNodeSnapshotFromSchema(common: common, fields: fields);
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
  final common = NodeBoundarySchema.snapshotCommonFromValidated((
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
  final fields = NodeBoundarySchema.textSnapshotFieldsFromValidated((
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
  ));
  return _textNodeSnapshotFromSchema(common: common, fields: fields);
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
  final common = NodeBoundarySchema.snapshotCommonFromValidated((
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
  final fields = NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: points,
    pointsRevision: pointsRevision,
    thickness: thickness,
    color: color,
  ));
  return _strokeNodeSnapshotFromSchema(common: common, fields: fields);
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
  final common = NodeBoundarySchema.snapshotCommonFromValidated((
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
  final fields = NodeBoundarySchema.lineFieldsFromValidated((
    start: start,
    end: end,
    thickness: thickness,
    color: color,
  ));
  return _lineNodeSnapshotFromSchema(common: common, fields: fields);
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
  final common = NodeBoundarySchema.snapshotCommonFromValidated((
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
  final fields = NodeBoundarySchema.rectFieldsFromValidated((
    size: size,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  ));
  return _rectNodeSnapshotFromSchema(common: common, fields: fields);
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
  final common = NodeBoundarySchema.snapshotCommonFromValidated((
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
  final fields = NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: svgPathData,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    fillRule: fillRule,
  ));
  return _pathNodeSnapshotFromSchema(common: common, fields: fields);
}
