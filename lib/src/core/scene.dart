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
  }) : layers = layers == null ? <Layer>[] : List<Layer>.from(layers),
       camera = camera ?? Camera(),
       background = background ?? Background(),
       palette = palette ?? ScenePalette();

  /// Layer list owned by the scene.
  ///
  /// The constructor defensively copies the `layers:` argument; mutating the
  /// original list after construction does not affect this scene.
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
    : nodes = nodes == null ? <SceneNode>[] : List<SceneNode>.from(nodes);

  /// Node list owned by the layer.
  ///
  /// The constructor defensively copies the `nodes:` argument; mutating the
  /// original list after construction does not affect this layer.
  final List<SceneNode> nodes;
  bool isBackground;
}

/// Viewport state for converting between view and scene coordinates.
class Camera {
  Camera({Offset? offset}) : offset = offset ?? Offset.zero;

  /// Camera pan in scene/world coordinates.
  ///
  /// Expected to have finite components.
  ///
  /// Runtime behavior: rendering and hit-testing sanitize non-finite components
  /// to `0` to avoid crashes; JSON serialization rejects invalid values.
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

  /// Grid cell size in scene/world units.
  ///
  /// Expected to be finite and `> 0` when [isEnabled] is true.
  ///
  /// Runtime behavior: rendering treats non-finite or non-positive values as
  /// "grid disabled"; JSON serialization rejects invalid values.
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
