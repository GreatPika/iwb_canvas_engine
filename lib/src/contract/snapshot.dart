import 'dart:ui';

import 'package:flutter/foundation.dart';

export 'ids.dart' show LayerId, NodeId, parseLayerId, parseNodeId;
export 'path_fill_rule.dart' show PathFillRule;
import 'ids.dart';
import 'internal/node_boundary_schema.dart';
import 'owned_collections.dart';
import 'path_fill_rule.dart';
import 'scene_defaults.dart';
import 'transform2d.dart';
import 'validated/finite_offset_value.dart';
import 'validated/layer_id_value.dart';
import 'validated/positive_finite_double_value.dart';

part 'internal/snapshot_fast_path.part.dart';

/// Immutable scene snapshot exposed by the public API.
class SceneSnapshot {
  factory SceneSnapshot({
    List<ContentLayerSnapshot>? layers,
    BackgroundLayerSnapshot? backgroundLayer,
    CameraSnapshot? camera,
    BackgroundSnapshot? background,
    ScenePaletteSnapshot? palette,
  }) {
    return SceneSnapshot._internal(
      layers: layers,
      backgroundLayer: backgroundLayer ?? BackgroundLayerSnapshot(),
      camera: _validateSceneCameraSnapshot(camera ?? const CameraSnapshot()),
      background: _validateSceneBackgroundSnapshot(
        background ?? const BackgroundSnapshot(),
      ),
      palette: palette ?? ScenePaletteSnapshot(),
    );
  }

  /// Internal fast path for already validated snapshot data.
  SceneSnapshot._internal({
    List<ContentLayerSnapshot>? layers,
    BackgroundLayerSnapshot? backgroundLayer,
    CameraSnapshot? camera,
    BackgroundSnapshot? background,
    ScenePaletteSnapshot? palette,
  }) : layers = List<ContentLayerSnapshot>.unmodifiable(
         layers == null
             ? const <ContentLayerSnapshot>[]
             : List<ContentLayerSnapshot>.from(layers),
       ),
       backgroundLayer = backgroundLayer ?? BackgroundLayerSnapshot._internal(),
       camera = camera ?? const CameraSnapshot(),
       background = background ?? const BackgroundSnapshot(),
       palette = palette ?? ScenePaletteSnapshot._internal();

  final List<ContentLayerSnapshot> layers;
  final BackgroundLayerSnapshot backgroundLayer;
  final CameraSnapshot camera;
  final BackgroundSnapshot background;
  final ScenePaletteSnapshot palette;
}

/// Immutable dedicated background layer snapshot.
class BackgroundLayerSnapshot {
  factory BackgroundLayerSnapshot({List<NodeSnapshot>? nodes}) {
    return BackgroundLayerSnapshot._internal(nodes: nodes);
  }

  /// Internal fast path for already validated snapshot data.
  BackgroundLayerSnapshot._internal({List<NodeSnapshot>? nodes})
    : nodes = List<NodeSnapshot>.unmodifiable(
        nodes == null ? <NodeSnapshot>[] : List<NodeSnapshot>.from(nodes),
      );

  final List<NodeSnapshot> nodes;
}

/// Immutable content layer snapshot.
class ContentLayerSnapshot {
  factory ContentLayerSnapshot({
    required LayerId id,
    List<NodeSnapshot>? nodes,
  }) {
    return ContentLayerSnapshot._internal(
      id: LayerIdValue.of(id, name: 'id').value,
      nodes: nodes,
    );
  }

  /// Internal fast path for already validated snapshot data.
  ContentLayerSnapshot._internal({required this.id, List<NodeSnapshot>? nodes})
    : nodes = List<NodeSnapshot>.unmodifiable(
        nodes == null ? <NodeSnapshot>[] : List<NodeSnapshot>.from(nodes),
      );

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
  factory ScenePaletteSnapshot({
    List<Color>? penColors,
    List<Color>? backgroundColors,
    List<double>? gridSizes,
  }) {
    final resolvedPenColors = List<Color>.from(
      penColors ?? SceneDefaults.penColors,
    );
    final resolvedBackgroundColors = List<Color>.from(
      backgroundColors ?? SceneDefaults.backgroundColors,
    );
    final resolvedGridSizes = List<double>.from(
      gridSizes ?? SceneDefaults.gridSizes,
    );
    _requireNonEmptyList(resolvedPenColors, name: 'penColors');
    _requireNonEmptyList(resolvedBackgroundColors, name: 'backgroundColors');
    _requireNonEmptyList(resolvedGridSizes, name: 'gridSizes');
    return ScenePaletteSnapshot._internal(
      penColors: resolvedPenColors,
      backgroundColors: resolvedBackgroundColors,
      gridSizes: resolvedGridSizes
          .map(
            (value) =>
                PositiveFiniteDoubleValue.of(value, name: 'gridSizes').value,
          )
          .toList(growable: false),
    );
  }

  /// Internal fast path for already validated snapshot data.
  ScenePaletteSnapshot._internal({
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

/// Immutable base node snapshot.
sealed class NodeSnapshot {
  const NodeSnapshot._internal({
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
  }) : this._internal(
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

  /// Internal fast path for already validated snapshot data.
  const ImageNodeSnapshot._internal({
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
  }) : super._internal();

  final String imageId;
  final Size size;
  final Size? naturalSize;
}

class TextNodeSnapshot extends NodeSnapshot {
  TextNodeSnapshot({
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
         )),
       );

  TextNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required TextNodeSnapshotSchemaFields fields,
  }) : this._internal(
         id: common.id,
         instanceRevision: common.instanceRevision,
         text: fields.text,
         size: fields.size,
         fontSize: fields.fontSize,
         color: fields.color,
         align: fields.align,
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

  /// Internal fast path for already validated snapshot data.
  const TextNodeSnapshot._internal({
    required super.id,
    super.instanceRevision,
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
  }) : super._internal();

  final String text;

  /// Canonical output metadata derived from text layout inputs.
  ///
  /// During snapshot import/canonicalization, the engine may ignore the input
  /// value and recompute it from `text`, font/style fields, and `maxWidth`.
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
           pointsRevision: pointsRevision,
           thickness: thickness,
           color: color,
         )),
       );

  StrokeNodeSnapshot._validated({
    required NodeSnapshotCommonSchemaFields common,
    required StrokeNodeSnapshotSchemaFields fields,
  }) : this._internal(
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

  /// Internal fast path for already validated snapshot data.
  StrokeNodeSnapshot._internal({
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
  }) : _points = OwnedList<Offset>.of(points),
       super._internal();

  final OwnedList<Offset> _points;
  List<Offset> get points => _points;
  final int pointsRevision;
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
  }) : this._internal(
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

  /// Internal fast path for already validated snapshot data.
  const LineNodeSnapshot._internal({
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
  }) : super._internal();

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
  }) : this._internal(
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

  /// Internal fast path for already validated snapshot data.
  const RectNodeSnapshot._internal({
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
  }) : super._internal();

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
  }) : this._internal(
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

  /// Internal fast path for already validated snapshot data.
  const PathNodeSnapshot._internal({
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
  }) : super._internal();

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

CameraSnapshot _validateSceneCameraSnapshot(CameraSnapshot value) {
  return CameraSnapshot(
    offset: FiniteOffsetValue.of(value.offset, name: 'camera.offset').value,
  );
}

BackgroundSnapshot _validateSceneBackgroundSnapshot(BackgroundSnapshot value) {
  return BackgroundSnapshot(
    color: value.color,
    grid: GridSnapshot(
      isEnabled: value.grid.isEnabled,
      cellSize: PositiveFiniteDoubleValue.of(
        value.grid.cellSize,
        name: 'background.grid.cellSize',
      ).value,
      color: value.grid.color,
    ),
  );
}
