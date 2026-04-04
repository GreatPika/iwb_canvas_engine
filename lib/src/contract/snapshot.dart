import 'dart:ui';

export 'ids.dart' show LayerId, NodeId, parseLayerId, parseNodeId;
export 'path_fill_rule.dart' show PathFillRule;
import 'ids.dart';
import 'internal/node_boundary_schema.dart';
import 'path_fill_rule.dart';
import 'scene_defaults.dart';
import 'scene_model_invariants.dart';
import 'scene_structure_validation.dart';
import 'transform2d.dart';
import 'validated/finite_offset_value.dart';
import 'validated/layer_id_value.dart';
import 'validated/positive_finite_double_value.dart';

/// Immutable scene snapshot exposed by the public API.
class SceneSnapshot {
  SceneSnapshot({
    List<ContentLayerSnapshot>? layers,
    BackgroundLayerSnapshot? backgroundLayer,
    CameraSnapshot? camera,
    BackgroundSnapshot? background,
    ScenePaletteSnapshot? palette,
  }) : this._validated(
         _validatedSceneSnapshotFields(
           layers: layers,
           backgroundLayer: backgroundLayer,
           camera: camera,
           background: background,
           palette: palette,
         ),
       );

  SceneSnapshot._validated(_SceneSnapshotFields fields)
    : layers = fields.layers,
      backgroundLayer = fields.backgroundLayer,
      camera = fields.camera,
      background = fields.background,
      palette = fields.palette;

  final List<ContentLayerSnapshot> layers;
  final BackgroundLayerSnapshot backgroundLayer;
  final CameraSnapshot camera;
  final BackgroundSnapshot background;
  final ScenePaletteSnapshot palette;
}

typedef _SceneSnapshotFields = ({
  List<ContentLayerSnapshot> layers,
  BackgroundLayerSnapshot backgroundLayer,
  CameraSnapshot camera,
  BackgroundSnapshot background,
  ScenePaletteSnapshot palette,
});

_SceneSnapshotFields _validatedSceneSnapshotFields({
  List<ContentLayerSnapshot>? layers,
  BackgroundLayerSnapshot? backgroundLayer,
  CameraSnapshot? camera,
  BackgroundSnapshot? background,
  ScenePaletteSnapshot? palette,
}) {
  final validatedLayers = List<ContentLayerSnapshot>.unmodifiable(
    List<ContentLayerSnapshot>.from(layers ?? const <ContentLayerSnapshot>[]),
  );
  final validatedBackgroundLayer = backgroundLayer ?? BackgroundLayerSnapshot();
  final validatedCamera = _validatedSceneCamera(camera);
  final validatedBackground = _validatedSceneBackground(background);
  final validatedPalette = palette ?? ScenePaletteSnapshot();

  sceneValidateSceneStructure<ContentLayerSnapshot, NodeSnapshot>(
    layers: validatedLayers,
    backgroundNodes: validatedBackgroundLayer.nodes,
    layerIdOf: (layer) => layer.id,
    nodesOf: (layer) => layer.nodes,
    nodeIdOf: (node) => node.id,
  );

  return (
    layers: validatedLayers,
    backgroundLayer: validatedBackgroundLayer,
    camera: validatedCamera,
    background: validatedBackground,
    palette: validatedPalette,
  );
}

/// Immutable dedicated background layer snapshot.
class BackgroundLayerSnapshot {
  BackgroundLayerSnapshot({List<NodeSnapshot>? nodes})
    : this._(
        nodes: List<NodeSnapshot>.unmodifiable(
          List<NodeSnapshot>.from(nodes ?? const <NodeSnapshot>[]),
        ),
      );

  BackgroundLayerSnapshot._({required this.nodes});

  final List<NodeSnapshot> nodes;
}

/// Immutable content layer snapshot.
class ContentLayerSnapshot {
  ContentLayerSnapshot({required LayerId id, List<NodeSnapshot>? nodes})
    : this._(
        id: LayerIdValue.of(id, name: 'id').value,
        nodes: List<NodeSnapshot>.unmodifiable(
          List<NodeSnapshot>.from(nodes ?? const <NodeSnapshot>[]),
        ),
      );

  ContentLayerSnapshot._({required this.id, required this.nodes});

  final LayerId id;
  final List<NodeSnapshot> nodes;
}

/// Immutable camera state snapshot.
class CameraSnapshot {
  const CameraSnapshot({this.offset = Offset.zero});

  final Offset offset;
}

/// Immutable background snapshot.
class BackgroundSnapshot {
  const BackgroundSnapshot({
    this.color = SceneDefaults.backgroundColor,
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
    this.color = SceneDefaults.gridColor,
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
  }) : this._(
         penColors: _validatedPenColors(penColors),
         backgroundColors: _validatedBackgroundColors(backgroundColors),
         gridSizes: _validatedGridSizes(gridSizes),
       );

  ScenePaletteSnapshot._({
    required this.penColors,
    required this.backgroundColors,
    required this.gridSizes,
  });

  final List<Color> penColors;
  final List<Color> backgroundColors;
  final List<double> gridSizes;
}

/// Immutable base node snapshot.
abstract class NodeSnapshot {
  const NodeSnapshot({
    required this.id,
    required this.instanceRevision,
    required this.transform,
    required this.opacity,
    required this.hitPadding,
    required this.isVisible,
    required this.isSelectable,
    required this.isLocked,
    required this.isDeletable,
    required this.isTransformable,
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

class ImageNodeSnapshot extends NodeSnapshot {
  ImageNodeSnapshot({
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
  }) : this._validated(
         common: validateSnapshotCommonSchemaFields((
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
         fields: validateImageNodeSchemaFields((
           imageId: imageId,
           size: size,
           naturalSize: naturalSize,
         )),
       );

  ImageNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required ImageNodeSchemaFields fields,
  }) : imageId = fields.imageId,
       size = fields.size,
       naturalSize = fields.naturalSize,
       super(
         id: common.id,
         instanceRevision: common.instanceRevision,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final String imageId;
  final Size size;
  final Size? naturalSize;
}

class TextNodeSnapshot extends NodeSnapshot {
  TextNodeSnapshot({
    required NodeId id,
    int instanceRevision = 0,
    required String text,
    double fontSize = 24,
    required Color color,
    TextAlign align = TextAlign.left,
    required TextDirection textDirection,
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
  }) : this._validated(
         common: validateSnapshotCommonSchemaFields((
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
         fields: validateTextNodeSnapshotSchemaFields((
           text: text,
           fontSize: fontSize,
           color: color,
           align: align,
           textDirection: textDirection,
           isBold: isBold,
           isItalic: isItalic,
           isUnderline: isUnderline,
           fontFamily: fontFamily,
           maxWidth: maxWidth,
           lineHeight: lineHeight,
         )),
       );

  TextNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required TextNodeSnapshotSchemaFields fields,
  }) : text = fields.text,
       fontSize = fields.fontSize,
       color = fields.color,
       align = fields.align,
       textDirection = fields.textDirection,
       isBold = fields.isBold,
       isItalic = fields.isItalic,
       isUnderline = fields.isUnderline,
       fontFamily = fields.fontFamily,
       maxWidth = fields.maxWidth,
       lineHeight = fields.lineHeight,
       super(
         id: common.id,
         instanceRevision: common.instanceRevision,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final String text;
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

class StrokeNodeSnapshot extends NodeSnapshot {
  StrokeNodeSnapshot({
    required NodeId id,
    int instanceRevision = 0,
    required List<Offset> points,
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
  }) : this._validated(
         common: validateSnapshotCommonSchemaFields((
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
         fields: validateStrokeNodeSnapshotSchemaFields((
           points: points,
           thickness: thickness,
           color: color,
         )),
       );

  StrokeNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required StrokeNodeSnapshotSchemaFields fields,
  }) : points = fields.points,
       thickness = fields.thickness,
       color = fields.color,
       super(
         id: common.id,
         instanceRevision: common.instanceRevision,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final List<Offset> points;
  final double thickness;
  final Color color;
}

class LineNodeSnapshot extends NodeSnapshot {
  LineNodeSnapshot({
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
  }) : this._validated(
         common: validateSnapshotCommonSchemaFields((
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
         fields: validateLineNodeSchemaFields((
           start: start,
           end: end,
           thickness: thickness,
           color: color,
         )),
       );

  LineNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required LineNodeSchemaFields fields,
  }) : start = fields.start,
       end = fields.end,
       thickness = fields.thickness,
       color = fields.color,
       super(
         id: common.id,
         instanceRevision: common.instanceRevision,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
}

class RectNodeSnapshot extends NodeSnapshot {
  RectNodeSnapshot({
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
  }) : this._validated(
         common: validateSnapshotCommonSchemaFields((
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
         fields: validateRectNodeSchemaFields((
           size: size,
           fillColor: fillColor,
           strokeColor: strokeColor,
           strokeWidth: strokeWidth,
         )),
       );

  RectNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required RectNodeSchemaFields fields,
  }) : size = fields.size,
       fillColor = fields.fillColor,
       strokeColor = fields.strokeColor,
       strokeWidth = fields.strokeWidth,
       super(
         id: common.id,
         instanceRevision: common.instanceRevision,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

class PathNodeSnapshot extends NodeSnapshot {
  PathNodeSnapshot({
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
  }) : this._validated(
         common: validateSnapshotCommonSchemaFields((
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
         fields: validatePathNodeSchemaFields((
           svgPathData: svgPathData,
           fillColor: fillColor,
           strokeColor: strokeColor,
           strokeWidth: strokeWidth,
           fillRule: fillRule,
         )),
       );

  PathNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required PathNodeSchemaFields fields,
  }) : svgPathData = fields.svgPathData,
       fillColor = fields.fillColor,
       strokeColor = fields.strokeColor,
       strokeWidth = fields.strokeWidth,
       fillRule = fields.fillRule,
       super(
         id: common.id,
         instanceRevision: common.instanceRevision,
         transform: common.transform,
         opacity: common.opacity,
         hitPadding: common.hitPadding,
         isVisible: common.isVisible,
         isSelectable: common.isSelectable,
         isLocked: common.isLocked,
         isDeletable: common.isDeletable,
         isTransformable: common.isTransformable,
       );

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final PathFillRule fillRule;
}

void _requireNonEmptyList<T>(List<T> values, {required String name}) {
  if (values.isNotEmpty) {
    return;
  }
  throw ArgumentError.value(values, name, 'Must not be empty.');
}

List<Color> _validatedPenColors(List<Color>? values) {
  final resolved = List<Color>.from(values ?? SceneDefaults.penColors);
  validatePaletteItemCount(
    resolved.length,
    name: 'penColors',
    source: resolved,
  );
  _requireNonEmptyList(resolved, name: 'penColors');
  return List<Color>.unmodifiable(resolved);
}

List<Color> _validatedBackgroundColors(List<Color>? values) {
  final resolved = List<Color>.from(values ?? SceneDefaults.backgroundColors);
  validatePaletteItemCount(
    resolved.length,
    name: 'backgroundColors',
    source: resolved,
  );
  _requireNonEmptyList(resolved, name: 'backgroundColors');
  return List<Color>.unmodifiable(resolved);
}

List<double> _validatedGridSizes(List<double>? values) {
  final resolved = List<double>.from(values ?? SceneDefaults.gridSizes);
  validatePaletteItemCount(
    resolved.length,
    name: 'gridSizes',
    source: resolved,
  );
  _requireNonEmptyList(resolved, name: 'gridSizes');
  return List<double>.unmodifiable(
    resolved
        .map(
          (value) =>
              PositiveFiniteDoubleValue.of(value, name: 'gridSizes').value,
        )
        .toList(growable: false),
  );
}

CameraSnapshot _validatedSceneCamera(CameraSnapshot? value) {
  final resolved = value ?? const CameraSnapshot();
  return CameraSnapshot(
    offset: FiniteOffsetValue.of(resolved.offset, name: 'camera.offset').value,
  );
}

BackgroundSnapshot _validatedSceneBackground(BackgroundSnapshot? value) {
  final resolved = value ?? const BackgroundSnapshot();
  return BackgroundSnapshot(
    color: resolved.color,
    grid: GridSnapshot(
      isEnabled: resolved.grid.isEnabled,
      cellSize: PositiveFiniteDoubleValue.of(
        resolved.grid.cellSize,
        name: 'background.grid.cellSize',
      ).value,
      color: resolved.grid.color,
    ),
  );
}
