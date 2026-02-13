import 'dart:ui';

import '../core/defaults.dart';
import '../core/transform2d.dart';

/// Stable node identifier for the v2 public model.
typedef NodeId = String;

/// Immutable scene snapshot exposed by the v2 public API.
class SceneSnapshot {
  SceneSnapshot({
    List<LayerSnapshot>? layers,
    CameraSnapshot? camera,
    BackgroundSnapshot? background,
    ScenePaletteSnapshot? palette,
  }) : layers = List<LayerSnapshot>.unmodifiable(
         layers == null
             ? const <LayerSnapshot>[]
             : List<LayerSnapshot>.from(layers),
       ),
       camera = camera ?? const CameraSnapshot(),
       background = background ?? const BackgroundSnapshot(),
       palette = palette ?? ScenePaletteSnapshot();

  final List<LayerSnapshot> layers;
  final CameraSnapshot camera;
  final BackgroundSnapshot background;
  final ScenePaletteSnapshot palette;
}

/// Immutable layer snapshot.
class LayerSnapshot {
  LayerSnapshot({List<NodeSnapshot>? nodes, this.isBackground = false})
    : nodes = List<NodeSnapshot>.unmodifiable(
        nodes == null ? const <NodeSnapshot>[] : List<NodeSnapshot>.from(nodes),
      );

  final List<NodeSnapshot> nodes;
  final bool isBackground;
}

/// Immutable camera state snapshot.
class CameraSnapshot {
  const CameraSnapshot({this.offset = Offset.zero});

  final Offset offset;
}

/// Immutable background snapshot.
class BackgroundSnapshot {
  const BackgroundSnapshot({
    this.color = const Color(0xFFFFFFFF),
    this.grid = const GridSnapshot(),
  });

  final Color color;
  final GridSnapshot grid;
}

/// Immutable grid settings snapshot.
class GridSnapshot {
  const GridSnapshot({
    this.isEnabled = false,
    this.cellSize = SceneDefaults.gridCellSize,
    this.color = const Color(0x1F000000),
  });

  final bool isEnabled;
  final double cellSize;
  final Color color;
}

/// Immutable palette snapshot.
class ScenePaletteSnapshot {
  ScenePaletteSnapshot({
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

/// Path fill rule value in the v2 public model.
enum V2PathFillRule { nonZero, evenOdd }

/// Immutable base node snapshot.
sealed class NodeSnapshot {
  const NodeSnapshot({
    required this.id,
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
  final Transform2D transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
}

class ImageNodeSnapshot extends NodeSnapshot {
  const ImageNodeSnapshot({
    required super.id,
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

class TextNodeSnapshot extends NodeSnapshot {
  const TextNodeSnapshot({
    required super.id,
    required this.text,
    required this.size,
    this.fontSize = 24,
    required this.color,
    this.align = TextAlign.left,
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
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}

class StrokeNodeSnapshot extends NodeSnapshot {
  StrokeNodeSnapshot({
    required super.id,
    required List<Offset> points,
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
  }) : points = List<Offset>.unmodifiable(List<Offset>.from(points));

  final List<Offset> points;
  final int pointsRevision;
  final double thickness;
  final Color color;
}

class LineNodeSnapshot extends NodeSnapshot {
  const LineNodeSnapshot({
    required super.id,
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

class RectNodeSnapshot extends NodeSnapshot {
  const RectNodeSnapshot({
    required super.id,
    required this.size,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
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

class PathNodeSnapshot extends NodeSnapshot {
  const PathNodeSnapshot({
    required super.id,
    required this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    this.fillRule = V2PathFillRule.nonZero,
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
  final V2PathFillRule fillRule;
}
