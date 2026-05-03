import 'dart:ui';

export 'ids.dart' show LayerId, NodeId, parseLayerId, parseNodeId;
export 'path_fill_rule.dart' show PathFillRule;
import 'ids.dart';
import 'internal/node_boundary_schema.dart';
import 'internal/snapshot_fast_path.dart'
    show
        backgroundLayerSnapshotBackingOf,
        backgroundSnapshotBackingOf,
        cameraSnapshotBackingOf,
        contentLayerSnapshotBackingOf,
        gridSnapshotBackingOf,
        nodeSnapshotBackingOf,
        scenePaletteSnapshotBackingOf;
import 'path_fill_rule.dart';
import 'scene_defaults.dart';
import 'scene_model_invariants.dart';
import 'scene_structure_validation.dart';
import 'transform2d.dart';
import 'validated/layer_id_value.dart';

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
    (layers ?? const <ContentLayerSnapshot>[])
        .map(_admitContentLayerSnapshot)
        .toList(growable: false),
  );
  final validatedBackgroundLayer = _admitBackgroundLayerSnapshot(
    backgroundLayer ?? BackgroundLayerSnapshot(),
  );
  final validatedCamera = _validatedSceneCamera(camera);
  final validatedBackground = _validatedSceneBackground(background);
  final validatedPalette = _admitScenePaletteSnapshot(
    palette ?? ScenePaletteSnapshot(),
  );

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
          (nodes ?? const <NodeSnapshot>[])
              .map(_admitNodeSnapshot)
              .toList(growable: false),
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
          (nodes ?? const <NodeSnapshot>[])
              .map(_admitNodeSnapshot)
              .toList(growable: false),
        ),
      );

  ContentLayerSnapshot._({required this.id, required this.nodes});

  final LayerId id;
  final List<NodeSnapshot> nodes;
}

/// Immutable camera state snapshot.
class CameraSnapshot {
  CameraSnapshot({Offset offset = Offset.zero})
    : offset = validateSceneCameraOffset(offset, name: 'offset');

  final Offset offset;
}

/// Immutable background snapshot.
class BackgroundSnapshot {
  BackgroundSnapshot({
    this.color = SceneDefaults.backgroundColor,
    GridSnapshot? grid,
  }) : grid = _validatedSceneGrid(grid);

  final Color color;
  final GridSnapshot grid;
}

/// Immutable grid settings snapshot.
class GridSnapshot {
  GridSnapshot({
    this.isEnabled = false,
    double cellSize = SceneDefaults.gridCellSize,
    this.color = SceneDefaults.gridColor,
  }) : cellSize = validateSceneGridCellSize(
         cellSize,
         name: 'cellSize',
         isEnabled: isEnabled,
       );

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

List<Color> _validatedPenColors(List<Color>? values) {
  return validateScenePaletteColorList(
    values ?? SceneDefaults.penColors,
    name: 'penColors',
  );
}

List<Color> _validatedBackgroundColors(List<Color>? values) {
  return validateScenePaletteColorList(
    values ?? SceneDefaults.backgroundColors,
    name: 'backgroundColors',
  );
}

List<double> _validatedGridSizes(List<double>? values) {
  return validateScenePaletteGridSizeList(
    values ?? SceneDefaults.gridSizes,
    name: 'gridSizes',
  );
}

CameraSnapshot _validatedSceneCamera(CameraSnapshot? value) {
  final resolved = value ?? CameraSnapshot();
  if (resolved.runtimeType == CameraSnapshot) {
    return resolved;
  }
  try {
    return CameraSnapshot(offset: cameraSnapshotBackingOf(resolved).offset);
  } on StateError {
    _throwUnsupportedBoundarySubtype(
      value: resolved,
      typeName: 'CameraSnapshot',
    );
  }
}

BackgroundSnapshot _validatedSceneBackground(BackgroundSnapshot? value) {
  final resolved = value ?? BackgroundSnapshot();
  if (resolved.runtimeType == BackgroundSnapshot) {
    return resolved;
  }
  try {
    final backing = backgroundSnapshotBackingOf(resolved);
    return BackgroundSnapshot(
      color: backing.color,
      grid: GridSnapshot(
        isEnabled: backing.grid.isEnabled,
        cellSize: backing.grid.cellSize,
        color: backing.grid.color,
      ),
    );
  } on StateError {
    _throwUnsupportedBoundarySubtype(
      value: resolved,
      typeName: 'BackgroundSnapshot',
    );
  }
}

GridSnapshot _validatedSceneGrid(GridSnapshot? value) {
  final resolved = value ?? GridSnapshot();
  if (resolved.runtimeType == GridSnapshot) {
    return resolved;
  }
  try {
    final backing = gridSnapshotBackingOf(resolved);
    return GridSnapshot(
      isEnabled: backing.isEnabled,
      cellSize: backing.cellSize,
      color: backing.color,
    );
  } on StateError {
    _throwUnsupportedBoundarySubtype(value: resolved, typeName: 'GridSnapshot');
  }
}

BackgroundLayerSnapshot _admitBackgroundLayerSnapshot(
  BackgroundLayerSnapshot layer,
) {
  if (layer.runtimeType == BackgroundLayerSnapshot) {
    return layer;
  }
  _requireSupportedBackgroundLayerSnapshotSubtype(layer);
  return BackgroundLayerSnapshot(nodes: layer.nodes);
}

ContentLayerSnapshot _admitContentLayerSnapshot(ContentLayerSnapshot layer) {
  if (layer.runtimeType == ContentLayerSnapshot) {
    return layer;
  }
  _requireSupportedContentLayerSnapshotSubtype(layer);
  return ContentLayerSnapshot(id: layer.id, nodes: layer.nodes);
}

ScenePaletteSnapshot _admitScenePaletteSnapshot(ScenePaletteSnapshot palette) {
  if (palette.runtimeType == ScenePaletteSnapshot) {
    return palette;
  }
  _requireSupportedScenePaletteSnapshotSubtype(palette);
  return ScenePaletteSnapshot(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
  );
}

NodeSnapshot _admitNodeSnapshot(NodeSnapshot snapshot) {
  switch (snapshot) {
    case ImageNodeSnapshot() when snapshot.runtimeType == ImageNodeSnapshot:
    case TextNodeSnapshot() when snapshot.runtimeType == TextNodeSnapshot:
    case StrokeNodeSnapshot() when snapshot.runtimeType == StrokeNodeSnapshot:
    case LineNodeSnapshot() when snapshot.runtimeType == LineNodeSnapshot:
    case RectNodeSnapshot() when snapshot.runtimeType == RectNodeSnapshot:
    case PathNodeSnapshot() when snapshot.runtimeType == PathNodeSnapshot:
      return snapshot;
    case ImageNodeSnapshot():
      _requireSupportedNodeSnapshotSubtype(snapshot);
      return ImageNodeSnapshot(
        id: snapshot.id,
        instanceRevision: snapshot.instanceRevision,
        imageId: snapshot.imageId,
        size: snapshot.size,
        naturalSize: snapshot.naturalSize,
        transform: snapshot.transform,
        opacity: snapshot.opacity,
        hitPadding: snapshot.hitPadding,
        isVisible: snapshot.isVisible,
        isSelectable: snapshot.isSelectable,
        isLocked: snapshot.isLocked,
        isDeletable: snapshot.isDeletable,
        isTransformable: snapshot.isTransformable,
      );
    case TextNodeSnapshot():
      _requireSupportedNodeSnapshotSubtype(snapshot);
      return TextNodeSnapshot(
        id: snapshot.id,
        instanceRevision: snapshot.instanceRevision,
        text: snapshot.text,
        fontSize: snapshot.fontSize,
        color: snapshot.color,
        align: snapshot.align,
        textDirection: snapshot.textDirection,
        isBold: snapshot.isBold,
        isItalic: snapshot.isItalic,
        isUnderline: snapshot.isUnderline,
        fontFamily: snapshot.fontFamily,
        maxWidth: snapshot.maxWidth,
        lineHeight: snapshot.lineHeight,
        transform: snapshot.transform,
        opacity: snapshot.opacity,
        hitPadding: snapshot.hitPadding,
        isVisible: snapshot.isVisible,
        isSelectable: snapshot.isSelectable,
        isLocked: snapshot.isLocked,
        isDeletable: snapshot.isDeletable,
        isTransformable: snapshot.isTransformable,
      );
    case StrokeNodeSnapshot():
      _requireSupportedNodeSnapshotSubtype(snapshot);
      return StrokeNodeSnapshot(
        id: snapshot.id,
        instanceRevision: snapshot.instanceRevision,
        points: snapshot.points,
        thickness: snapshot.thickness,
        color: snapshot.color,
        transform: snapshot.transform,
        opacity: snapshot.opacity,
        hitPadding: snapshot.hitPadding,
        isVisible: snapshot.isVisible,
        isSelectable: snapshot.isSelectable,
        isLocked: snapshot.isLocked,
        isDeletable: snapshot.isDeletable,
        isTransformable: snapshot.isTransformable,
      );
    case LineNodeSnapshot():
      _requireSupportedNodeSnapshotSubtype(snapshot);
      return LineNodeSnapshot(
        id: snapshot.id,
        instanceRevision: snapshot.instanceRevision,
        start: snapshot.start,
        end: snapshot.end,
        thickness: snapshot.thickness,
        color: snapshot.color,
        transform: snapshot.transform,
        opacity: snapshot.opacity,
        hitPadding: snapshot.hitPadding,
        isVisible: snapshot.isVisible,
        isSelectable: snapshot.isSelectable,
        isLocked: snapshot.isLocked,
        isDeletable: snapshot.isDeletable,
        isTransformable: snapshot.isTransformable,
      );
    case RectNodeSnapshot():
      _requireSupportedNodeSnapshotSubtype(snapshot);
      return RectNodeSnapshot(
        id: snapshot.id,
        instanceRevision: snapshot.instanceRevision,
        size: snapshot.size,
        fillColor: snapshot.fillColor,
        strokeColor: snapshot.strokeColor,
        strokeWidth: snapshot.strokeWidth,
        transform: snapshot.transform,
        opacity: snapshot.opacity,
        hitPadding: snapshot.hitPadding,
        isVisible: snapshot.isVisible,
        isSelectable: snapshot.isSelectable,
        isLocked: snapshot.isLocked,
        isDeletable: snapshot.isDeletable,
        isTransformable: snapshot.isTransformable,
      );
    case PathNodeSnapshot():
      _requireSupportedNodeSnapshotSubtype(snapshot);
      return PathNodeSnapshot(
        id: snapshot.id,
        instanceRevision: snapshot.instanceRevision,
        svgPathData: snapshot.svgPathData,
        fillColor: snapshot.fillColor,
        strokeColor: snapshot.strokeColor,
        strokeWidth: snapshot.strokeWidth,
        fillRule: snapshot.fillRule,
        transform: snapshot.transform,
        opacity: snapshot.opacity,
        hitPadding: snapshot.hitPadding,
        isVisible: snapshot.isVisible,
        isSelectable: snapshot.isSelectable,
        isLocked: snapshot.isLocked,
        isDeletable: snapshot.isDeletable,
        isTransformable: snapshot.isTransformable,
      );
    case _:
      _throwUnsupportedBoundarySubtype(
        value: snapshot,
        typeName: 'NodeSnapshot',
      );
  }
}

void _requireSupportedBackgroundLayerSnapshotSubtype(
  BackgroundLayerSnapshot layer,
) {
  try {
    backgroundLayerSnapshotBackingOf(layer);
  } on StateError {
    _throwUnsupportedBoundarySubtype(
      value: layer,
      typeName: 'BackgroundLayerSnapshot',
    );
  }
}

void _requireSupportedContentLayerSnapshotSubtype(ContentLayerSnapshot layer) {
  try {
    contentLayerSnapshotBackingOf(layer);
  } on StateError {
    _throwUnsupportedBoundarySubtype(
      value: layer,
      typeName: 'ContentLayerSnapshot',
    );
  }
}

void _requireSupportedScenePaletteSnapshotSubtype(
  ScenePaletteSnapshot palette,
) {
  try {
    scenePaletteSnapshotBackingOf(palette);
  } on StateError {
    _throwUnsupportedBoundarySubtype(
      value: palette,
      typeName: 'ScenePaletteSnapshot',
    );
  }
}

void _requireSupportedNodeSnapshotSubtype(NodeSnapshot snapshot) {
  try {
    nodeSnapshotBackingOf(snapshot);
  } on StateError {
    _throwUnsupportedBoundarySubtype(value: snapshot, typeName: 'NodeSnapshot');
  }
}

Never _throwUnsupportedBoundarySubtype({
  required Object value,
  required String typeName,
}) {
  throw StateError(
    'Unsupported $typeName subtype at admission: ${value.runtimeType}.',
  );
}
