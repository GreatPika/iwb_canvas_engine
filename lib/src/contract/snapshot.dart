import 'dart:ui';

import 'package:flutter/foundation.dart';

export 'ids.dart' show LayerId, NodeId, parseLayerId, parseNodeId;
export 'path_fill_rule.dart' show PathFillRule;
import 'ids.dart';
import 'owned_collections.dart';
import 'path_fill_rule.dart';
import 'scene_defaults.dart';
import 'transform2d.dart';
import 'validated/finite_offset_value.dart';
import 'validated/font_family_value.dart';
import 'validated/image_id_value.dart';
import 'validated/instance_revision_value.dart';
import 'validated/layer_id_value.dart';
import 'validated/node_id_value.dart';
import 'validated/non_negative_finite_double_value.dart';
import 'validated/opacity_value.dart';
import 'validated/positive_finite_double_value.dart';
import 'validated/svg_path_data_value.dart';
import 'validated/text_content_value.dart';
import 'validated/validated_value_support.dart';

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
  factory ImageNodeSnapshot({
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
  }) {
    final common = _validateNodeSnapshotCommonFields(
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
    );
    return ImageNodeSnapshot._internal(
      id: common.id,
      instanceRevision: common.instanceRevision,
      imageId: ImageIdValue.of(imageId, name: 'imageId').value,
      size: _validateNonNegativeSize(size, name: 'size'),
      naturalSize: naturalSize == null
          ? null
          : _validateNonNegativeSize(naturalSize, name: 'naturalSize'),
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
  factory TextNodeSnapshot({
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
  }) {
    final common = _validateNodeSnapshotCommonFields(
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
    );
    return TextNodeSnapshot._internal(
      id: common.id,
      instanceRevision: common.instanceRevision,
      text: TextContentValue.of(text, name: 'text').value,
      size: _validateNonNegativeSize(size, name: 'size'),
      fontSize: PositiveFiniteDoubleValue.of(fontSize, name: 'fontSize').value,
      color: color,
      align: align,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      fontFamily: fontFamily == null
          ? null
          : FontFamilyValue.of(fontFamily, name: 'fontFamily').value,
      maxWidth: maxWidth == null
          ? null
          : PositiveFiniteDoubleValue.of(maxWidth, name: 'maxWidth').value,
      lineHeight: lineHeight == null
          ? null
          : PositiveFiniteDoubleValue.of(lineHeight, name: 'lineHeight').value,
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
  factory StrokeNodeSnapshot({
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
  }) {
    final common = _validateNodeSnapshotCommonFields(
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
    );
    final validatedPoints = List<Offset>.from(points, growable: false)
        .asMap()
        .entries
        .map(
          (entry) => FiniteOffsetValue.of(
            entry.value,
            name: 'points[${entry.key}]',
          ).value,
        )
        .toList(growable: false);
    return StrokeNodeSnapshot._internal(
      id: common.id,
      instanceRevision: common.instanceRevision,
      points: validatedPoints,
      pointsRevision: InstanceRevisionValue.of(
        pointsRevision,
        name: 'pointsRevision',
        allowZero: true,
      ).value,
      thickness: PositiveFiniteDoubleValue.of(
        thickness,
        name: 'thickness',
      ).value,
      color: color,
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
  factory LineNodeSnapshot({
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
  }) {
    final common = _validateNodeSnapshotCommonFields(
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
    );
    return LineNodeSnapshot._internal(
      id: common.id,
      instanceRevision: common.instanceRevision,
      start: FiniteOffsetValue.of(start, name: 'start').value,
      end: FiniteOffsetValue.of(end, name: 'end').value,
      thickness: PositiveFiniteDoubleValue.of(
        thickness,
        name: 'thickness',
      ).value,
      color: color,
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
  factory RectNodeSnapshot({
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
  }) {
    final common = _validateNodeSnapshotCommonFields(
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
    );
    return RectNodeSnapshot._internal(
      id: common.id,
      instanceRevision: common.instanceRevision,
      size: _validateNonNegativeSize(size, name: 'size'),
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: NonNegativeFiniteDoubleValue.of(
        strokeWidth,
        name: 'strokeWidth',
      ).value,
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
  factory PathNodeSnapshot({
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
  }) {
    final common = _validateNodeSnapshotCommonFields(
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
    );
    return PathNodeSnapshot._internal(
      id: common.id,
      instanceRevision: common.instanceRevision,
      svgPathData: SvgPathDataValue.of(svgPathData, name: 'svgPathData').value,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: NonNegativeFiniteDoubleValue.of(
        strokeWidth,
        name: 'strokeWidth',
      ).value,
      fillRule: fillRule,
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

class _ValidatedNodeSnapshotCommonFields {
  const _ValidatedNodeSnapshotCommonFields({
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

_ValidatedNodeSnapshotCommonFields _validateNodeSnapshotCommonFields({
  required NodeId id,
  required int instanceRevision,
  required Transform2D transform,
  required double opacity,
  required double hitPadding,
  required bool isVisible,
  required bool isSelectable,
  required bool isLocked,
  required bool isDeletable,
  required bool isTransformable,
}) {
  return _ValidatedNodeSnapshotCommonFields(
    id: NodeIdValue.of(id, name: 'id').value,
    instanceRevision: InstanceRevisionValue.of(
      instanceRevision,
      name: 'instanceRevision',
      allowZero: true,
    ).value,
    transform: _validateFiniteInvertibleTransform2D(
      transform,
      name: 'transform',
    ),
    opacity: OpacityValue.of(opacity, name: 'opacity').value,
    hitPadding: NonNegativeFiniteDoubleValue.of(
      hitPadding,
      name: 'hitPadding',
    ).value,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

Transform2D _validateFiniteInvertibleTransform2D(
  Transform2D value, {
  required String name,
}) {
  validatedRequireFiniteDouble(value.a, name: '$name.a');
  validatedRequireFiniteDouble(value.b, name: '$name.b');
  validatedRequireFiniteDouble(value.c, name: '$name.c');
  validatedRequireFiniteDouble(value.d, name: '$name.d');
  validatedRequireFiniteDouble(value.tx, name: '$name.tx');
  validatedRequireFiniteDouble(value.ty, name: '$name.ty');
  if (value.invert() == null) {
    throw ArgumentError.value(
      value.toJsonMap(),
      name,
      'Must be invertible (non-singular).',
    );
  }
  return value;
}

Size _validateNonNegativeSize(Size value, {required String name}) {
  NonNegativeFiniteDoubleValue.of(value.width, name: '$name.width');
  NonNegativeFiniteDoubleValue.of(value.height, name: '$name.height');
  return value;
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
