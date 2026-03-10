import 'dart:ui';

import '../contract/ids.dart' show LayerId;
import '../contract/scene_defaults.dart';
import 'nodes.dart';

/// A mutable scene graph used by the canvas engine.
///
/// Runtime scenes may keep [backgroundLayer] absent as an internal shape until
/// a write path needs to materialize it. Snapshot/JSON boundaries canonicalize
/// the same concept into a dedicated always-present background layer, so this
/// nullable field is a runtime detail rather than a competing source of truth.
///
/// Content [layers] stay ordered, with a [camera] offset and background visual
/// settings. Nodes are stored with local geometry and positioned into
/// scene/world coordinates via [SceneNode.transform].
class Scene {
  Scene({
    List<ContentLayer>? layers,
    this.backgroundLayer,
    Camera? camera,
    Background? background,
    ScenePalette? palette,
  }) : layers = layers == null
           ? <ContentLayer>[]
           : List<ContentLayer>.from(layers),
       camera = camera ?? Camera(),
       background = background ?? Background(),
       palette = palette ?? ScenePalette();

  /// Content layer list owned by the scene.
  ///
  /// The constructor defensively copies the `layers:` argument; mutating the
  /// original list after construction does not affect this scene.
  final List<ContentLayer> layers;

  /// Optional runtime background layer rendered below all content layers.
  ///
  /// Runtime code may leave this `null` until a mutation path explicitly needs
  /// background nodes. Snapshot and JSON boundaries canonicalize the same state
  /// into a dedicated non-null background layer.
  BackgroundLayer? backgroundLayer;

  Camera camera;
  Background background;
  ScenePalette palette;
}

/// A dedicated background node layer.
///
/// Runtime scenes may materialize this layer lazily; typed and JSON boundaries
/// always treat it as a dedicated single layer below content layers.
class BackgroundLayer {
  BackgroundLayer({List<SceneNode>? nodes})
    : nodes = nodes == null ? <SceneNode>[] : List<SceneNode>.from(nodes);

  /// Node list owned by the layer.
  ///
  /// The constructor defensively copies the `nodes:` argument; mutating the
  /// original list after construction does not affect this layer.
  final List<SceneNode> nodes;
}

/// A z-ordered collection of content nodes.
///
/// Layers are rendered in list order. Nodes inside a layer are rendered in
/// list order; the last node is considered the top-most for hit-testing.
class ContentLayer {
  ContentLayer({required this.id, List<SceneNode>? nodes})
    : nodes = nodes == null ? <SceneNode>[] : List<SceneNode>.from(nodes);

  final LayerId id;

  /// Node list owned by the layer.
  ///
  /// The constructor defensively copies the `nodes:` argument; mutating the
  /// original list after construction does not affect this layer.
  final List<SceneNode> nodes;
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
