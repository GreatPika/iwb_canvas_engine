import 'dart:ui';

import '../ids.dart';
import '../owned_collections.dart';
import '../path_fill_rule.dart';
import '../scene_defaults.dart';
import '../transform2d.dart';
import 'node_boundary_schema.dart';

final class SceneSnapshotBacking {
  SceneSnapshotBacking({
    List<ContentLayerSnapshotBacking>? layers,
    BackgroundLayerSnapshotBacking? backgroundLayer,
    CameraSnapshotBacking? camera,
    BackgroundSnapshotBacking? background,
    ScenePaletteSnapshotBacking? palette,
  }) : layers = List<ContentLayerSnapshotBacking>.unmodifiable(
         layers == null
             ? const <ContentLayerSnapshotBacking>[]
             : List<ContentLayerSnapshotBacking>.from(layers),
       ),
       backgroundLayer =
           backgroundLayer ?? BackgroundLayerSnapshotBacking(nodes: const []),
       camera = camera ?? const CameraSnapshotBacking(),
       background = background ?? const BackgroundSnapshotBacking(),
       palette = palette ?? ScenePaletteSnapshotBacking();

  final List<ContentLayerSnapshotBacking> layers;
  final BackgroundLayerSnapshotBacking backgroundLayer;
  final CameraSnapshotBacking camera;
  final BackgroundSnapshotBacking background;
  final ScenePaletteSnapshotBacking palette;
}

final class BackgroundLayerSnapshotBacking {
  BackgroundLayerSnapshotBacking({List<NodeSnapshotBacking>? nodes})
    : nodes = List<NodeSnapshotBacking>.unmodifiable(
        nodes == null
            ? const <NodeSnapshotBacking>[]
            : List<NodeSnapshotBacking>.from(nodes),
      );

  final List<NodeSnapshotBacking> nodes;
}

final class ContentLayerSnapshotBacking {
  ContentLayerSnapshotBacking({
    required this.id,
    List<NodeSnapshotBacking>? nodes,
  }) : nodes = List<NodeSnapshotBacking>.unmodifiable(
         nodes == null
             ? const <NodeSnapshotBacking>[]
             : List<NodeSnapshotBacking>.from(nodes),
       );

  final LayerId id;
  final List<NodeSnapshotBacking> nodes;
}

final class CameraSnapshotBacking {
  const CameraSnapshotBacking({this.offset = Offset.zero});

  final Offset offset;
}

final class BackgroundSnapshotBacking {
  const BackgroundSnapshotBacking({
    this.color = SceneDefaults.backgroundColor,
    this.grid = const GridSnapshotBacking(),
  });

  final Color color;
  final GridSnapshotBacking grid;
}

final class GridSnapshotBacking {
  const GridSnapshotBacking({
    this.isEnabled = false,
    this.cellSize = SceneDefaults.gridCellSize,
    this.color = SceneDefaults.gridColor,
  });

  final bool isEnabled;
  final double cellSize;
  final Color color;
}

final class ScenePaletteSnapshotBacking {
  ScenePaletteSnapshotBacking({
    List<Color>? penColors,
    List<Color>? backgroundColors,
    List<double>? gridSizes,
  }) : penColors = List<Color>.unmodifiable(
         penColors == null
             ? SceneDefaults.penColors
             : List<Color>.from(penColors),
       ),
       backgroundColors = List<Color>.unmodifiable(
         backgroundColors == null
             ? SceneDefaults.backgroundColors
             : List<Color>.from(backgroundColors),
       ),
       gridSizes = List<double>.unmodifiable(
         gridSizes == null
             ? SceneDefaults.gridSizes
             : List<double>.from(gridSizes),
       );

  final List<Color> penColors;
  final List<Color> backgroundColors;
  final List<double> gridSizes;
}

sealed class NodeSnapshotBacking {
  const NodeSnapshotBacking({
    required this.id,
    this.instanceRevision = 0,
    this.transform = Transform2D.identity,
    this.opacity = 1,
    this.hitPadding = 0,
    this.isVisible = true,
    this.isSelectable = true,
    this.isLocked = false,
    this.isDeletable = true,
    this.isTransformable = true,
  });

  final NodeId id;
  final int instanceRevision;
  final Transform2D transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
}

final class ImageNodeSnapshotBacking extends NodeSnapshotBacking {
  const ImageNodeSnapshotBacking({
    required super.id,
    super.instanceRevision,
    required this.imageId,
    required this.size,
    this.naturalSize,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final String imageId;
  final Size size;
  final Size? naturalSize;
}

final class TextNodeSnapshotBacking extends NodeSnapshotBacking {
  const TextNodeSnapshotBacking({
    required super.id,
    super.instanceRevision,
    required this.text,
    required this.size,
    this.fontSize = 24,
    required this.color,
    this.align = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final String text;
  final Size size;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection textDirection;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}

final class StrokeNodeSnapshotBacking extends NodeSnapshotBacking {
  StrokeNodeSnapshotBacking({
    required super.id,
    super.instanceRevision,
    required Iterable<Offset> points,
    this.pointsRevision = 0,
    required this.thickness,
    required this.color,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  }) : points = OwnedList<Offset>.of(points);

  final OwnedList<Offset> points;
  final int pointsRevision;
  final double thickness;
  final Color color;
}

final class LineNodeSnapshotBacking extends NodeSnapshotBacking {
  const LineNodeSnapshotBacking({
    required super.id,
    super.instanceRevision,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
}

final class RectNodeSnapshotBacking extends NodeSnapshotBacking {
  const RectNodeSnapshotBacking({
    required super.id,
    super.instanceRevision,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

final class PathNodeSnapshotBacking extends NodeSnapshotBacking {
  const PathNodeSnapshotBacking({
    required super.id,
    super.instanceRevision,
    required this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0,
    this.fillRule = PathFillRule.nonZero,
    super.transform,
    super.opacity,
    super.hitPadding,
    super.isVisible,
    super.isSelectable,
    super.isLocked,
    super.isDeletable,
    super.isTransformable,
  });

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final PathFillRule fillRule;
}

SceneSnapshotBacking sceneSnapshotBackingFromValidated({
  List<ContentLayerSnapshotBacking>? layers,
  BackgroundLayerSnapshotBacking? backgroundLayer,
  CameraSnapshotBacking? camera,
  BackgroundSnapshotBacking? background,
  ScenePaletteSnapshotBacking? palette,
}) {
  return SceneSnapshotBacking(
    layers: layers,
    backgroundLayer: backgroundLayer,
    camera: camera,
    background: background,
    palette: palette,
  );
}

BackgroundLayerSnapshotBacking backgroundLayerSnapshotBackingFromValidated({
  List<NodeSnapshotBacking>? nodes,
}) {
  return BackgroundLayerSnapshotBacking(nodes: nodes);
}

ContentLayerSnapshotBacking contentLayerSnapshotBackingFromValidated({
  required LayerId id,
  List<NodeSnapshotBacking>? nodes,
}) {
  return ContentLayerSnapshotBacking(id: id, nodes: nodes);
}

CameraSnapshotBacking cameraSnapshotBackingFromValidated({
  Offset offset = Offset.zero,
}) {
  return CameraSnapshotBacking(offset: offset);
}

BackgroundSnapshotBacking backgroundSnapshotBackingFromValidated({
  Color color = SceneDefaults.backgroundColor,
  GridSnapshotBacking grid = const GridSnapshotBacking(),
}) {
  return BackgroundSnapshotBacking(color: color, grid: grid);
}

GridSnapshotBacking gridSnapshotBackingFromValidated({
  bool isEnabled = false,
  double cellSize = SceneDefaults.gridCellSize,
  Color color = SceneDefaults.gridColor,
}) {
  return GridSnapshotBacking(
    isEnabled: isEnabled,
    cellSize: cellSize,
    color: color,
  );
}

ScenePaletteSnapshotBacking scenePaletteSnapshotBackingFromValidated({
  List<Color>? penColors,
  List<Color>? backgroundColors,
  List<double>? gridSizes,
}) {
  return ScenePaletteSnapshotBacking(
    penColors: penColors,
    backgroundColors: backgroundColors,
    gridSizes: gridSizes,
  );
}

ImageNodeSnapshotBacking imageNodeSnapshotBackingFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required ImageNodeSchemaFields fields,
}) {
  return ImageNodeSnapshotBacking(
    id: common.id,
    instanceRevision: common.instanceRevision,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

TextNodeSnapshotBacking textNodeSnapshotBackingFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required TextNodeSnapshotSchemaFields fields,
}) {
  return TextNodeSnapshotBacking(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: fields.size,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    textDirection: fields.textDirection,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

StrokeNodeSnapshotBacking strokeNodeSnapshotBackingFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
  return StrokeNodeSnapshotBacking(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    pointsRevision: fields.pointsRevision,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

LineNodeSnapshotBacking lineNodeSnapshotBackingFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required LineNodeSchemaFields fields,
}) {
  return LineNodeSnapshotBacking(
    id: common.id,
    instanceRevision: common.instanceRevision,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

RectNodeSnapshotBacking rectNodeSnapshotBackingFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return RectNodeSnapshotBacking(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

PathNodeSnapshotBacking pathNodeSnapshotBackingFromValidated({
  required NodeSnapshotCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return PathNodeSnapshotBacking(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}
