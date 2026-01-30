import 'dart:ui';

import 'defaults.dart';
import 'nodes.dart';

/// A mutable scene graph used by the canvas engine.
///
/// The scene is organized into ordered [layers], with a [camera] offset and
/// background settings. Nodes are stored in scene coordinates.
class Scene {
  Scene({
    List<Layer>? layers,
    Camera? camera,
    Background? background,
    ScenePalette? palette,
  }) : layers = layers ?? <Layer>[],
       camera = camera ?? Camera(),
       background = background ?? Background(),
       palette = palette ?? ScenePalette();

  final List<Layer> layers;
  Camera camera;
  Background background;
  ScenePalette palette;
}

/// A z-ordered collection of nodes.
///
/// Layers are rendered in list order. Nodes inside a layer are rendered in
/// list order; the last node is considered the top-most for hit-testing.
class Layer {
  Layer({List<SceneNode>? nodes, this.isBackground = false})
    : nodes = nodes ?? <SceneNode>[];

  final List<SceneNode> nodes;
  bool isBackground;
}

/// Viewport state for converting between view and scene coordinates.
class Camera {
  Camera({Offset? offset}) : offset = offset ?? Offset.zero;

  Offset offset;
}

/// Background visual settings: solid [color] and optional [grid].
class Background {
  Background({Color? color, GridSettings? grid})
    : color = color ?? SceneDefaults.backgroundColors.first,
      grid = grid ?? GridSettings();

  Color color;
  GridSettings grid;
}

/// Grid rendering configuration.
class GridSettings {
  GridSettings({this.isEnabled = false, double? cellSize, Color? color})
    : cellSize = cellSize ?? SceneDefaults.gridSizes.first,
      color = color ?? SceneDefaults.gridColor;

  bool isEnabled;
  double cellSize;
  Color color;
}

/// Palette presets for tool colors and background/grid options.
class ScenePalette {
  ScenePalette({
    List<Color>? penColors,
    List<Color>? backgroundColors,
    List<double>? gridSizes,
  }) : penColors = List<Color>.from(penColors ?? SceneDefaults.penColors),
       backgroundColors = List<Color>.from(
         backgroundColors ?? SceneDefaults.backgroundColors,
       ),
       gridSizes = List<double>.from(gridSizes ?? SceneDefaults.gridSizes);

  final List<Color> penColors;
  final List<Color> backgroundColors;
  final List<double> gridSizes;
}
