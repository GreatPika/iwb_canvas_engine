import 'dart:ui';

import 'defaults.dart';
import 'nodes.dart';

class Scene {
  Scene({
    List<Layer>? layers,
    Camera? camera,
    Background? background,
    ScenePalette? palette,
  })  : layers = layers ?? <Layer>[],
        camera = camera ?? Camera(),
        background = background ?? Background(),
        palette = palette ?? ScenePalette();

  final List<Layer> layers;
  Camera camera;
  Background background;
  ScenePalette palette;
}

class Layer {
  Layer({
    List<SceneNode>? nodes,
    this.isBackground = false,
  }) : nodes = nodes ?? <SceneNode>[];

  final List<SceneNode> nodes;
  bool isBackground;
}

class Camera {
  Camera({Offset? offset}) : offset = offset ?? Offset.zero;

  Offset offset;
}

class Background {
  Background({
    Color? color,
    GridSettings? grid,
  })  : color = color ?? SceneDefaults.backgroundColors.first,
        grid = grid ?? GridSettings();

  Color color;
  GridSettings grid;
}

class GridSettings {
  GridSettings({
    this.isEnabled = false,
    double? cellSize,
    Color? color,
  })  : cellSize = cellSize ?? SceneDefaults.gridSizes.first,
        color = color ?? SceneDefaults.gridColor;

  bool isEnabled;
  double cellSize;
  Color color;
}

class ScenePalette {
  ScenePalette({
    List<Color>? penColors,
    List<Color>? backgroundColors,
    List<double>? gridSizes,
  })  : penColors = List<Color>.from(
          penColors ?? SceneDefaults.penColors,
        ),
        backgroundColors = List<Color>.from(
          backgroundColors ?? SceneDefaults.backgroundColors,
        ),
        gridSizes = List<double>.from(
          gridSizes ?? SceneDefaults.gridSizes,
        );

  final List<Color> penColors;
  final List<Color> backgroundColors;
  final List<double> gridSizes;
}
