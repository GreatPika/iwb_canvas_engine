import 'dart:ui';

import '../contract/ids.dart' show LayerId;
import '../contract/scene_model_invariants.dart';
import '../contract/scene_defaults.dart';
import 'grid_safety_limits.dart';
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
  GridSettings({bool isEnabled = false, double? cellSize, Color? color})
    : _isEnabled = false,
      _cellSize = _requireFinitePositiveGridCellSize(
        cellSize ?? SceneDefaults.gridSizes.first,
        name: 'cellSize',
      ),
      color = color ?? SceneDefaults.gridColor {
    if (isEnabled) {
      this.isEnabled = true;
    }
  }

  bool get isEnabled => _isEnabled;
  bool _isEnabled;
  set isEnabled(bool value) {
    if (value && _cellSize < kMinGridCellSize) {
      throw ArgumentError.value(
        value,
        'isEnabled',
        'Cannot enable grid when cellSize is < $kMinGridCellSize.',
      );
    }
    _isEnabled = value;
  }

  /// Grid cell size in scene/world units.
  ///
  /// Expected to be finite and `> 0`.
  ///
  /// Runtime behavior: invalid values throw at assignment; enabling the grid
  /// also requires `cellSize >= kMinGridCellSize`. JSON serialization rejects
  /// invalid values.
  double get cellSize => _cellSize;
  double _cellSize;
  set cellSize(double value) {
    final nextValue = _requireFinitePositiveGridCellSize(
      value,
      name: 'cellSize',
    );
    if (_isEnabled && nextValue < kMinGridCellSize) {
      throw ArgumentError.value(
        value,
        'cellSize',
        'Must be >= $kMinGridCellSize while the grid is enabled.',
      );
    }
    _cellSize = nextValue;
  }

  Color color;
}

/// Palette presets for tool colors and background/grid options.
class ScenePalette {
  ScenePalette({
    List<Color>? penColors,
    List<Color>? backgroundColors,
    List<double>? gridSizes,
  }) : penColors = _ownedPaletteColors(
         penColors ?? SceneDefaults.penColors,
         name: 'penColors',
       ),
       backgroundColors = _ownedPaletteColors(
         backgroundColors ?? SceneDefaults.backgroundColors,
         name: 'backgroundColors',
       ),
       gridSizes = _ownedPaletteGridSizes(
         gridSizes ?? SceneDefaults.gridSizes,
         name: 'gridSizes',
       );

  /// Immutable runtime palette presets.
  ///
  /// Constructor inputs are defensively copied and frozen, so runtime palette
  /// updates use replacement-only semantics at the [Scene.palette] field.
  final List<Color> penColors;
  final List<Color> backgroundColors;
  final List<double> gridSizes;
}

List<Color> _ownedPaletteColors(List<Color> values, {required String name}) {
  validatePaletteItemCount(values.length, name: name, source: values);
  return List<Color>.unmodifiable(List<Color>.from(values));
}

List<double> _ownedPaletteGridSizes(
  List<double> values, {
  required String name,
}) {
  validatePaletteItemCount(values.length, name: name, source: values);
  return List<double>.unmodifiable(List<double>.from(values));
}

double _requireFinitePositiveGridCellSize(
  double value, {
  required String name,
}) {
  if (value.isFinite && value > 0) {
    return value;
  }
  throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
}
