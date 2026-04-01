import 'dart:ui';

import 'package:flutter/foundation.dart';

export 'ids.dart' show LayerId, NodeId, parseLayerId, parseNodeId;
export 'path_fill_rule.dart' show PathFillRule;
import 'ids.dart';
import 'internal/node_boundary_schema.dart';
import 'internal/snapshot_backing.dart';
import 'internal/snapshot_materialization.dart';
import 'path_fill_rule.dart';
import 'scene_defaults.dart';
import 'transform2d.dart';
import 'validated/finite_offset_value.dart';
import 'validated/layer_id_value.dart';
import 'validated/positive_finite_double_value.dart';
import 'scene_model_invariants.dart';

/// Immutable scene snapshot exposed by the public API.
class SceneSnapshot {
  factory SceneSnapshot({
    List<ContentLayerSnapshot>? layers,
    BackgroundLayerSnapshot? backgroundLayer,
    CameraSnapshot? camera,
    BackgroundSnapshot? background,
    ScenePaletteSnapshot? palette,
  }) {
    return SceneSnapshot.materialize(
      sceneSnapshotBackingFromValidated(
        layers: layers
            ?.map((layer) => layer.internalBacking)
            .toList(growable: false),
        backgroundLayer: backgroundLayer?.internalBacking,
        camera: _validateSceneCameraBacking(camera ?? const CameraSnapshot()),
        background: _validateSceneBackgroundBacking(
          background ?? const BackgroundSnapshot(),
        ),
        palette: palette?.internalBacking,
      ),
    );
  }

  @internal
  factory SceneSnapshot.materialize(SceneSnapshotBacking backing) =
      SceneSnapshot._materialized;

  SceneSnapshot._materialized(this._backing);

  final SceneSnapshotBacking _backing;

  @internal
  SceneSnapshotBacking get internalBacking => _backing;

  late final List<ContentLayerSnapshot> _layers =
      materializeContentLayerSnapshotList(_backing.layers);
  late final BackgroundLayerSnapshot _backgroundLayer =
      materializeBackgroundLayerSnapshot(_backing.backgroundLayer);
  late final CameraSnapshot _camera = materializeCameraSnapshot(
    _backing.camera,
  );
  late final BackgroundSnapshot _background = materializeBackgroundSnapshot(
    _backing.background,
  );
  late final ScenePaletteSnapshot _palette = materializeScenePaletteSnapshot(
    _backing.palette,
  );

  List<ContentLayerSnapshot> get layers => _layers;
  BackgroundLayerSnapshot get backgroundLayer => _backgroundLayer;
  CameraSnapshot get camera => _camera;
  BackgroundSnapshot get background => _background;
  ScenePaletteSnapshot get palette => _palette;
}

/// Immutable dedicated background layer snapshot.
class BackgroundLayerSnapshot {
  factory BackgroundLayerSnapshot({List<NodeSnapshot>? nodes}) {
    return BackgroundLayerSnapshot.materialize(
      backgroundLayerSnapshotBackingFromValidated(
        nodes: nodes
            ?.map((node) => node.internalBacking)
            .toList(growable: false),
      ),
    );
  }

  @internal
  factory BackgroundLayerSnapshot.materialize(
    BackgroundLayerSnapshotBacking backing,
  ) = BackgroundLayerSnapshot._materialized;

  BackgroundLayerSnapshot._materialized(this._backing);

  final BackgroundLayerSnapshotBacking _backing;

  @internal
  BackgroundLayerSnapshotBacking get internalBacking => _backing;

  late final List<NodeSnapshot> _nodes = materializeNodeSnapshotList(
    _backing.nodes,
  );

  List<NodeSnapshot> get nodes => _nodes;
}

/// Immutable content layer snapshot.
class ContentLayerSnapshot {
  factory ContentLayerSnapshot({
    required LayerId id,
    List<NodeSnapshot>? nodes,
  }) {
    return ContentLayerSnapshot.materialize(
      contentLayerSnapshotBackingFromValidated(
        id: LayerIdValue.of(id, name: 'id').value,
        nodes: nodes
            ?.map((node) => node.internalBacking)
            .toList(growable: false),
      ),
    );
  }

  @internal
  factory ContentLayerSnapshot.materialize(
    ContentLayerSnapshotBacking backing,
  ) = ContentLayerSnapshot._materialized;

  ContentLayerSnapshot._materialized(this._backing);

  final ContentLayerSnapshotBacking _backing;

  @internal
  ContentLayerSnapshotBacking get internalBacking => _backing;

  late final List<NodeSnapshot> _nodes = materializeNodeSnapshotList(
    _backing.nodes,
  );

  LayerId get id => _backing.id;
  List<NodeSnapshot> get nodes => _nodes;
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
    validatePaletteItemCount(
      resolvedPenColors.length,
      name: 'penColors',
      source: resolvedPenColors,
    );
    validatePaletteItemCount(
      resolvedBackgroundColors.length,
      name: 'backgroundColors',
      source: resolvedBackgroundColors,
    );
    validatePaletteItemCount(
      resolvedGridSizes.length,
      name: 'gridSizes',
      source: resolvedGridSizes,
    );
    _requireNonEmptyList(resolvedPenColors, name: 'penColors');
    _requireNonEmptyList(resolvedBackgroundColors, name: 'backgroundColors');
    _requireNonEmptyList(resolvedGridSizes, name: 'gridSizes');
    return ScenePaletteSnapshot.materialize(
      scenePaletteSnapshotBackingFromValidated(
        penColors: resolvedPenColors,
        backgroundColors: resolvedBackgroundColors,
        gridSizes: resolvedGridSizes
            .map(
              (value) =>
                  PositiveFiniteDoubleValue.of(value, name: 'gridSizes').value,
            )
            .toList(growable: false),
      ),
    );
  }

  @internal
  factory ScenePaletteSnapshot.materialize(
    ScenePaletteSnapshotBacking backing,
  ) = ScenePaletteSnapshot._materialized;

  ScenePaletteSnapshot._materialized(this._backing);

  final ScenePaletteSnapshotBacking _backing;

  @internal
  ScenePaletteSnapshotBacking get internalBacking => _backing;

  List<Color> get penColors => _backing.penColors;
  List<Color> get backgroundColors => _backing.backgroundColors;
  List<double> get gridSizes => _backing.gridSizes;
}

/// Immutable base node snapshot.
sealed class NodeSnapshot {
  NodeSnapshot._materialized(this._backing);

  final NodeSnapshotBacking _backing;

  @internal
  NodeSnapshotBacking get internalBacking => _backing;

  NodeId get id => _backing.id;
  int get instanceRevision => _backing.instanceRevision;
  Transform2D get transform => _backing.transform;
  double get opacity => _backing.opacity;
  double get hitPadding => _backing.hitPadding;
  bool get isVisible => _backing.isVisible;
  bool get isSelectable => _backing.isSelectable;
  bool get isLocked => _backing.isLocked;
  bool get isDeletable => _backing.isDeletable;
  bool get isTransformable => _backing.isTransformable;
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
  }) : this._materialized(
         imageNodeSnapshotBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory ImageNodeSnapshot.materialize(ImageNodeSnapshotBacking backing) =
      ImageNodeSnapshot._materialized;

  ImageNodeSnapshot._materialized(super._backing) : super._materialized();

  ImageNodeSnapshotBacking get _imageBacking =>
      internalBacking as ImageNodeSnapshotBacking;

  String get imageId => _imageBacking.imageId;
  Size get size => _imageBacking.size;
  Size? get naturalSize => _imageBacking.naturalSize;
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
           size: size,
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
  }) : this._materialized(
         textNodeSnapshotBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory TextNodeSnapshot.materialize(TextNodeSnapshotBacking backing) =
      TextNodeSnapshot._materialized;

  TextNodeSnapshot._materialized(super._backing) : super._materialized();

  TextNodeSnapshotBacking get _textBacking =>
      internalBacking as TextNodeSnapshotBacking;

  /// Canonical output metadata derived from text layout inputs.
  ///
  /// During snapshot import/canonicalization, the engine may ignore the input
  /// value and recompute it from `text`, font/style fields, and `maxWidth`.
  String get text => _textBacking.text;
  Size get size => _textBacking.size;
  double get fontSize => _textBacking.fontSize;
  Color get color => _textBacking.color;
  TextAlign get align => _textBacking.align;
  TextDirection get textDirection => _textBacking.textDirection;
  bool get isBold => _textBacking.isBold;
  bool get isItalic => _textBacking.isItalic;
  bool get isUnderline => _textBacking.isUnderline;
  String? get fontFamily => _textBacking.fontFamily;
  double? get maxWidth => _textBacking.maxWidth;
  double? get lineHeight => _textBacking.lineHeight;
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
  }) : this._materialized(
         strokeNodeSnapshotBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory StrokeNodeSnapshot.materialize(StrokeNodeSnapshotBacking backing) =
      StrokeNodeSnapshot._materialized;

  StrokeNodeSnapshot._materialized(super._backing) : super._materialized();

  StrokeNodeSnapshotBacking get _strokeBacking =>
      internalBacking as StrokeNodeSnapshotBacking;

  List<Offset> get points => _strokeBacking.points;
  int get pointsRevision => _strokeBacking.pointsRevision;
  double get thickness => _strokeBacking.thickness;
  Color get color => _strokeBacking.color;
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
  }) : this._materialized(
         lineNodeSnapshotBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory LineNodeSnapshot.materialize(LineNodeSnapshotBacking backing) =
      LineNodeSnapshot._materialized;

  LineNodeSnapshot._materialized(super._backing) : super._materialized();

  LineNodeSnapshotBacking get _lineBacking =>
      internalBacking as LineNodeSnapshotBacking;

  Offset get start => _lineBacking.start;
  Offset get end => _lineBacking.end;
  double get thickness => _lineBacking.thickness;
  Color get color => _lineBacking.color;
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
  }) : this._materialized(
         rectNodeSnapshotBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory RectNodeSnapshot.materialize(RectNodeSnapshotBacking backing) =
      RectNodeSnapshot._materialized;

  RectNodeSnapshot._materialized(super._backing) : super._materialized();

  RectNodeSnapshotBacking get _rectBacking =>
      internalBacking as RectNodeSnapshotBacking;

  Size get size => _rectBacking.size;
  Color? get fillColor => _rectBacking.fillColor;
  Color? get strokeColor => _rectBacking.strokeColor;
  double get strokeWidth => _rectBacking.strokeWidth;
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
  }) : this._materialized(
         pathNodeSnapshotBackingFromValidated(common: common, fields: fields),
       );

  @internal
  factory PathNodeSnapshot.materialize(PathNodeSnapshotBacking backing) =
      PathNodeSnapshot._materialized;

  PathNodeSnapshot._materialized(super._backing) : super._materialized();

  PathNodeSnapshotBacking get _pathBacking =>
      internalBacking as PathNodeSnapshotBacking;

  String get svgPathData => _pathBacking.svgPathData;
  Color? get fillColor => _pathBacking.fillColor;
  Color? get strokeColor => _pathBacking.strokeColor;
  double get strokeWidth => _pathBacking.strokeWidth;
  PathFillRule get fillRule => _pathBacking.fillRule;
}

void _requireNonEmptyList<T>(List<T> values, {required String name}) {
  if (values.isNotEmpty) {
    return;
  }
  throw ArgumentError.value(values, name, 'Must not be empty.');
}

CameraSnapshotBacking _validateSceneCameraBacking(CameraSnapshot value) {
  return cameraSnapshotBackingFromValidated(
    offset: FiniteOffsetValue.of(value.offset, name: 'camera.offset').value,
  );
}

BackgroundSnapshotBacking _validateSceneBackgroundBacking(
  BackgroundSnapshot value,
) {
  return backgroundSnapshotBackingFromValidated(
    color: value.color,
    grid: gridSnapshotBackingFromValidated(
      isEnabled: value.grid.isEnabled,
      cellSize: PositiveFiniteDoubleValue.of(
        value.grid.cellSize,
        name: 'background.grid.cellSize',
      ).value,
      color: value.grid.color,
    ),
  );
}
