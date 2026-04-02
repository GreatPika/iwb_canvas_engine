import 'dart:ui';

import '../snapshot.dart';
import '../transform2d.dart';
import 'boundary_impl_support.dart';
import 'snapshot_backing.dart';
import 'snapshot_node_boundary_fallback.dart';

abstract interface class SceneSnapshotBackingCarrier {
  SceneSnapshotBacking get sceneSnapshotBacking;
}

abstract interface class BackgroundLayerSnapshotBackingCarrier {
  BackgroundLayerSnapshotBacking get backgroundLayerSnapshotBacking;
}

abstract interface class ContentLayerSnapshotBackingCarrier {
  ContentLayerSnapshotBacking get contentLayerSnapshotBacking;
}

abstract interface class ScenePaletteSnapshotBackingCarrier {
  ScenePaletteSnapshotBacking get scenePaletteSnapshotBacking;
}

abstract interface class NodeSnapshotBackingCarrier {
  NodeSnapshotBacking get nodeSnapshotBacking;
}

final Expando<SceneSnapshotBacking> _sceneSnapshotBackingCache =
    Expando<SceneSnapshotBacking>('sceneSnapshotBacking');
final Expando<BackgroundLayerSnapshotBacking> _backgroundLayerBackingCache =
    Expando<BackgroundLayerSnapshotBacking>('backgroundLayerSnapshotBacking');
final Expando<ContentLayerSnapshotBacking> _contentLayerBackingCache =
    Expando<ContentLayerSnapshotBacking>('contentLayerSnapshotBacking');
final Expando<ScenePaletteSnapshotBacking> _paletteBackingCache =
    Expando<ScenePaletteSnapshotBacking>('scenePaletteSnapshotBacking');
final Expando<NodeSnapshotBacking> _nodeSnapshotBackingCache =
    Expando<NodeSnapshotBacking>('nodeSnapshotBacking');

final _sceneSnapshotBackingResolver =
    BoundaryBackingResolver<SceneSnapshot, SceneSnapshotBacking>(
      cache: _sceneSnapshotBackingCache,
      readCarrier: _sceneSnapshotBackingFromCarrier,
      rebuild: _rebuildSceneSnapshotBacking,
    );

final _backgroundLayerSnapshotBackingResolver =
    BoundaryBackingResolver<
      BackgroundLayerSnapshot,
      BackgroundLayerSnapshotBacking
    >(
      cache: _backgroundLayerBackingCache,
      readCarrier: _backgroundLayerSnapshotBackingFromCarrier,
      rebuild: _rebuildBackgroundLayerSnapshotBacking,
    );

final _contentLayerSnapshotBackingResolver =
    BoundaryBackingResolver<ContentLayerSnapshot, ContentLayerSnapshotBacking>(
      cache: _contentLayerBackingCache,
      readCarrier: _contentLayerSnapshotBackingFromCarrier,
      rebuild: _rebuildContentLayerSnapshotBacking,
    );

final _scenePaletteSnapshotBackingResolver =
    BoundaryBackingResolver<ScenePaletteSnapshot, ScenePaletteSnapshotBacking>(
      cache: _paletteBackingCache,
      readCarrier: _scenePaletteSnapshotBackingFromCarrier,
      rebuild: _rebuildScenePaletteSnapshotBacking,
    );

final _nodeSnapshotBackingResolver =
    BoundaryBackingResolver<NodeSnapshot, NodeSnapshotBacking>(
      cache: _nodeSnapshotBackingCache,
      readCarrier: _nodeSnapshotBackingFromCarrier,
      rebuild: publicNodeSnapshotBackingOf,
    );

SceneSnapshotBacking sceneSnapshotBackingOf(SceneSnapshot snapshot) =>
    _sceneSnapshotBackingResolver.resolve(snapshot);

BackgroundLayerSnapshotBacking backgroundLayerSnapshotBackingOf(
  BackgroundLayerSnapshot layer,
) {
  return _backgroundLayerSnapshotBackingResolver.resolve(layer);
}

ContentLayerSnapshotBacking contentLayerSnapshotBackingOf(
  ContentLayerSnapshot layer,
) {
  return _contentLayerSnapshotBackingResolver.resolve(layer);
}

ScenePaletteSnapshotBacking scenePaletteSnapshotBackingOf(
  ScenePaletteSnapshot palette,
) {
  return _scenePaletteSnapshotBackingResolver.resolve(palette);
}

NodeSnapshotBacking nodeSnapshotBackingOf(NodeSnapshot snapshot) =>
    _nodeSnapshotBackingResolver.resolve(snapshot);

SceneSnapshotBacking? _sceneSnapshotBackingFromCarrier(SceneSnapshot snapshot) {
  return readBoundaryBackingCarrier(
    snapshot,
    (carrier) => (carrier as SceneSnapshotBackingCarrier).sceneSnapshotBacking,
  );
}

BackgroundLayerSnapshotBacking? _backgroundLayerSnapshotBackingFromCarrier(
  BackgroundLayerSnapshot layer,
) {
  return readBoundaryBackingCarrier(
    layer,
    (carrier) => (carrier as BackgroundLayerSnapshotBackingCarrier)
        .backgroundLayerSnapshotBacking,
  );
}

ContentLayerSnapshotBacking? _contentLayerSnapshotBackingFromCarrier(
  ContentLayerSnapshot layer,
) {
  return readBoundaryBackingCarrier(
    layer,
    (carrier) => (carrier as ContentLayerSnapshotBackingCarrier)
        .contentLayerSnapshotBacking,
  );
}

ScenePaletteSnapshotBacking? _scenePaletteSnapshotBackingFromCarrier(
  ScenePaletteSnapshot palette,
) {
  return readBoundaryBackingCarrier(
    palette,
    (carrier) => (carrier as ScenePaletteSnapshotBackingCarrier)
        .scenePaletteSnapshotBacking,
  );
}

NodeSnapshotBacking? _nodeSnapshotBackingFromCarrier(NodeSnapshot snapshot) {
  return readBoundaryBackingCarrier(
    snapshot,
    (carrier) => (carrier as NodeSnapshotBackingCarrier).nodeSnapshotBacking,
  );
}

SceneSnapshotBacking _rebuildSceneSnapshotBacking(SceneSnapshot snapshot) {
  requireExactBoundaryRuntimeType(
    value: snapshot,
    exactType: SceneSnapshot,
    typeName: 'SceneSnapshot',
  );
  return SceneSnapshotBacking(
    layers: snapshot.layers
        .map(contentLayerSnapshotBackingOf)
        .toList(growable: false),
    backgroundLayer: backgroundLayerSnapshotBackingOf(snapshot.backgroundLayer),
    camera: _cameraSnapshotBackingOf(snapshot.camera),
    background: _backgroundSnapshotBackingOf(snapshot.background),
    palette: scenePaletteSnapshotBackingOf(snapshot.palette),
  );
}

BackgroundLayerSnapshotBacking _rebuildBackgroundLayerSnapshotBacking(
  BackgroundLayerSnapshot layer,
) {
  requireExactBoundaryRuntimeType(
    value: layer,
    exactType: BackgroundLayerSnapshot,
    typeName: 'BackgroundLayerSnapshot',
  );
  return BackgroundLayerSnapshotBacking(
    nodes: layer.nodes.map(nodeSnapshotBackingOf).toList(growable: false),
  );
}

ContentLayerSnapshotBacking _rebuildContentLayerSnapshotBacking(
  ContentLayerSnapshot layer,
) {
  requireExactBoundaryRuntimeType(
    value: layer,
    exactType: ContentLayerSnapshot,
    typeName: 'ContentLayerSnapshot',
  );
  return ContentLayerSnapshotBacking(
    id: layer.id,
    nodes: layer.nodes.map(nodeSnapshotBackingOf).toList(growable: false),
  );
}

ScenePaletteSnapshotBacking _rebuildScenePaletteSnapshotBacking(
  ScenePaletteSnapshot palette,
) {
  requireExactBoundaryRuntimeType(
    value: palette,
    exactType: ScenePaletteSnapshot,
    typeName: 'ScenePaletteSnapshot',
  );
  return ScenePaletteSnapshotBacking(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
  );
}

SceneSnapshot materializeSceneSnapshotForInternalUse(
  SceneSnapshotBacking backing,
) {
  return _MaterializedSceneSnapshot(backing);
}

BackgroundLayerSnapshot materializeBackgroundLayerSnapshotForInternalUse(
  BackgroundLayerSnapshotBacking backing,
) {
  return _MaterializedBackgroundLayerSnapshot(backing);
}

ContentLayerSnapshot materializeContentLayerSnapshotForInternalUse(
  ContentLayerSnapshotBacking backing,
) {
  return _MaterializedContentLayerSnapshot(backing);
}

ScenePaletteSnapshot materializeScenePaletteSnapshotForInternalUse(
  ScenePaletteSnapshotBacking backing,
) {
  return _MaterializedScenePaletteSnapshot(backing);
}

NodeSnapshot materializeNodeSnapshotForInternalUse(
  NodeSnapshotBacking backing,
) {
  return switch (backing) {
    ImageNodeSnapshotBacking image => _MaterializedImageNodeSnapshot(image),
    TextNodeSnapshotBacking text => _MaterializedTextNodeSnapshot(text),
    StrokeNodeSnapshotBacking stroke => _MaterializedStrokeNodeSnapshot(stroke),
    LineNodeSnapshotBacking line => _MaterializedLineNodeSnapshot(line),
    RectNodeSnapshotBacking rect => _MaterializedRectNodeSnapshot(rect),
    PathNodeSnapshotBacking path => _MaterializedPathNodeSnapshot(path),
  };
}

final class _MaterializedSceneSnapshot extends SceneSnapshot
    implements SceneSnapshotBackingCarrier {
  _MaterializedSceneSnapshot(this.sceneSnapshotBacking) : super();

  @override
  final SceneSnapshotBacking sceneSnapshotBacking;

  late final List<ContentLayerSnapshot> _layers =
      List<ContentLayerSnapshot>.unmodifiable(
        sceneSnapshotBacking.layers.map(
          materializeContentLayerSnapshotForInternalUse,
        ),
      );

  late final BackgroundLayerSnapshot _backgroundLayer =
      materializeBackgroundLayerSnapshotForInternalUse(
        sceneSnapshotBacking.backgroundLayer,
      );

  late final CameraSnapshot _camera = CameraSnapshot(
    offset: sceneSnapshotBacking.camera.offset,
  );

  late final BackgroundSnapshot _background = BackgroundSnapshot(
    color: sceneSnapshotBacking.background.color,
    grid: GridSnapshot(
      isEnabled: sceneSnapshotBacking.background.grid.isEnabled,
      cellSize: sceneSnapshotBacking.background.grid.cellSize,
      color: sceneSnapshotBacking.background.grid.color,
    ),
  );

  late final ScenePaletteSnapshot _palette =
      materializeScenePaletteSnapshotForInternalUse(
        sceneSnapshotBacking.palette,
      );

  @override
  List<ContentLayerSnapshot> get layers => _layers;

  @override
  BackgroundLayerSnapshot get backgroundLayer => _backgroundLayer;

  @override
  CameraSnapshot get camera => _camera;

  @override
  BackgroundSnapshot get background => _background;

  @override
  ScenePaletteSnapshot get palette => _palette;
}

final class _MaterializedBackgroundLayerSnapshot extends BackgroundLayerSnapshot
    implements BackgroundLayerSnapshotBackingCarrier {
  _MaterializedBackgroundLayerSnapshot(this.backgroundLayerSnapshotBacking)
    : super();

  @override
  final BackgroundLayerSnapshotBacking backgroundLayerSnapshotBacking;

  late final List<NodeSnapshot> _nodes = List<NodeSnapshot>.unmodifiable(
    backgroundLayerSnapshotBacking.nodes.map(
      materializeNodeSnapshotForInternalUse,
    ),
  );

  @override
  List<NodeSnapshot> get nodes => _nodes;
}

final class _MaterializedContentLayerSnapshot extends ContentLayerSnapshot
    implements ContentLayerSnapshotBackingCarrier {
  _MaterializedContentLayerSnapshot(this.contentLayerSnapshotBacking)
    : super(id: _placeholderLayerId);

  @override
  final ContentLayerSnapshotBacking contentLayerSnapshotBacking;

  late final List<NodeSnapshot> _nodes = List<NodeSnapshot>.unmodifiable(
    contentLayerSnapshotBacking.nodes.map(
      materializeNodeSnapshotForInternalUse,
    ),
  );

  @override
  LayerId get id => contentLayerSnapshotBacking.id;

  @override
  List<NodeSnapshot> get nodes => _nodes;
}

final class _MaterializedScenePaletteSnapshot extends ScenePaletteSnapshot
    implements ScenePaletteSnapshotBackingCarrier {
  _MaterializedScenePaletteSnapshot(this.scenePaletteSnapshotBacking) : super();

  @override
  final ScenePaletteSnapshotBacking scenePaletteSnapshotBacking;

  @override
  List<Color> get penColors => scenePaletteSnapshotBacking.penColors;

  @override
  List<Color> get backgroundColors =>
      scenePaletteSnapshotBacking.backgroundColors;

  @override
  List<double> get gridSizes => scenePaletteSnapshotBacking.gridSizes;
}

final class _MaterializedImageNodeSnapshot extends ImageNodeSnapshot
    implements NodeSnapshotBackingCarrier {
  _MaterializedImageNodeSnapshot(this.nodeSnapshotBacking)
    : super(
        id: _placeholderNodeId,
        imageId: _placeholderImageId,
        size: _placeholderSize,
      );

  @override
  final ImageNodeSnapshotBacking nodeSnapshotBacking;

  @override
  NodeId get id => nodeSnapshotBacking.id;

  @override
  int get instanceRevision => nodeSnapshotBacking.instanceRevision;

  @override
  Transform2D get transform => nodeSnapshotBacking.transform;

  @override
  double get opacity => nodeSnapshotBacking.opacity;

  @override
  double get hitPadding => nodeSnapshotBacking.hitPadding;

  @override
  bool get isVisible => nodeSnapshotBacking.isVisible;

  @override
  bool get isSelectable => nodeSnapshotBacking.isSelectable;

  @override
  bool get isLocked => nodeSnapshotBacking.isLocked;

  @override
  bool get isDeletable => nodeSnapshotBacking.isDeletable;

  @override
  bool get isTransformable => nodeSnapshotBacking.isTransformable;

  @override
  String get imageId => nodeSnapshotBacking.imageId;

  @override
  Size get size => nodeSnapshotBacking.size;

  @override
  Size? get naturalSize => nodeSnapshotBacking.naturalSize;
}

final class _MaterializedTextNodeSnapshot extends TextNodeSnapshot
    implements NodeSnapshotBackingCarrier {
  _MaterializedTextNodeSnapshot(this.nodeSnapshotBacking)
    : super(
        id: _placeholderNodeId,
        text: _placeholderText,
        color: _placeholderColor,
        textDirection: TextDirection.ltr,
      );

  @override
  final TextNodeSnapshotBacking nodeSnapshotBacking;

  @override
  NodeId get id => nodeSnapshotBacking.id;

  @override
  int get instanceRevision => nodeSnapshotBacking.instanceRevision;

  @override
  Transform2D get transform => nodeSnapshotBacking.transform;

  @override
  double get opacity => nodeSnapshotBacking.opacity;

  @override
  double get hitPadding => nodeSnapshotBacking.hitPadding;

  @override
  bool get isVisible => nodeSnapshotBacking.isVisible;

  @override
  bool get isSelectable => nodeSnapshotBacking.isSelectable;

  @override
  bool get isLocked => nodeSnapshotBacking.isLocked;

  @override
  bool get isDeletable => nodeSnapshotBacking.isDeletable;

  @override
  bool get isTransformable => nodeSnapshotBacking.isTransformable;

  @override
  String get text => nodeSnapshotBacking.text;

  @override
  double get fontSize => nodeSnapshotBacking.fontSize;

  @override
  Color get color => nodeSnapshotBacking.color;

  @override
  TextAlign get align => nodeSnapshotBacking.align;

  @override
  TextDirection get textDirection => nodeSnapshotBacking.textDirection;

  @override
  bool get isBold => nodeSnapshotBacking.isBold;

  @override
  bool get isItalic => nodeSnapshotBacking.isItalic;

  @override
  bool get isUnderline => nodeSnapshotBacking.isUnderline;

  @override
  String? get fontFamily => nodeSnapshotBacking.fontFamily;

  @override
  double? get maxWidth => nodeSnapshotBacking.maxWidth;

  @override
  double? get lineHeight => nodeSnapshotBacking.lineHeight;
}

final class _MaterializedStrokeNodeSnapshot extends StrokeNodeSnapshot
    implements NodeSnapshotBackingCarrier {
  _MaterializedStrokeNodeSnapshot(this.nodeSnapshotBacking)
    : super(
        id: _placeholderNodeId,
        points: _placeholderStrokePoints,
        thickness: 1,
        color: _placeholderColor,
      );

  @override
  final StrokeNodeSnapshotBacking nodeSnapshotBacking;

  @override
  NodeId get id => nodeSnapshotBacking.id;

  @override
  int get instanceRevision => nodeSnapshotBacking.instanceRevision;

  @override
  Transform2D get transform => nodeSnapshotBacking.transform;

  @override
  double get opacity => nodeSnapshotBacking.opacity;

  @override
  double get hitPadding => nodeSnapshotBacking.hitPadding;

  @override
  bool get isVisible => nodeSnapshotBacking.isVisible;

  @override
  bool get isSelectable => nodeSnapshotBacking.isSelectable;

  @override
  bool get isLocked => nodeSnapshotBacking.isLocked;

  @override
  bool get isDeletable => nodeSnapshotBacking.isDeletable;

  @override
  bool get isTransformable => nodeSnapshotBacking.isTransformable;

  @override
  List<Offset> get points => nodeSnapshotBacking.points;

  @override
  int get pointsRevision => nodeSnapshotBacking.pointsRevision;

  @override
  double get thickness => nodeSnapshotBacking.thickness;

  @override
  Color get color => nodeSnapshotBacking.color;
}

final class _MaterializedLineNodeSnapshot extends LineNodeSnapshot
    implements NodeSnapshotBackingCarrier {
  _MaterializedLineNodeSnapshot(this.nodeSnapshotBacking)
    : super(
        id: _placeholderNodeId,
        start: Offset.zero,
        end: const Offset(1, 0),
        thickness: 1,
        color: _placeholderColor,
      );

  @override
  final LineNodeSnapshotBacking nodeSnapshotBacking;

  @override
  NodeId get id => nodeSnapshotBacking.id;

  @override
  int get instanceRevision => nodeSnapshotBacking.instanceRevision;

  @override
  Transform2D get transform => nodeSnapshotBacking.transform;

  @override
  double get opacity => nodeSnapshotBacking.opacity;

  @override
  double get hitPadding => nodeSnapshotBacking.hitPadding;

  @override
  bool get isVisible => nodeSnapshotBacking.isVisible;

  @override
  bool get isSelectable => nodeSnapshotBacking.isSelectable;

  @override
  bool get isLocked => nodeSnapshotBacking.isLocked;

  @override
  bool get isDeletable => nodeSnapshotBacking.isDeletable;

  @override
  bool get isTransformable => nodeSnapshotBacking.isTransformable;

  @override
  Offset get start => nodeSnapshotBacking.start;

  @override
  Offset get end => nodeSnapshotBacking.end;

  @override
  double get thickness => nodeSnapshotBacking.thickness;

  @override
  Color get color => nodeSnapshotBacking.color;
}

final class _MaterializedRectNodeSnapshot extends RectNodeSnapshot
    implements NodeSnapshotBackingCarrier {
  _MaterializedRectNodeSnapshot(this.nodeSnapshotBacking)
    : super(id: _placeholderNodeId, size: _placeholderSize);

  @override
  final RectNodeSnapshotBacking nodeSnapshotBacking;

  @override
  NodeId get id => nodeSnapshotBacking.id;

  @override
  int get instanceRevision => nodeSnapshotBacking.instanceRevision;

  @override
  Transform2D get transform => nodeSnapshotBacking.transform;

  @override
  double get opacity => nodeSnapshotBacking.opacity;

  @override
  double get hitPadding => nodeSnapshotBacking.hitPadding;

  @override
  bool get isVisible => nodeSnapshotBacking.isVisible;

  @override
  bool get isSelectable => nodeSnapshotBacking.isSelectable;

  @override
  bool get isLocked => nodeSnapshotBacking.isLocked;

  @override
  bool get isDeletable => nodeSnapshotBacking.isDeletable;

  @override
  bool get isTransformable => nodeSnapshotBacking.isTransformable;

  @override
  Size get size => nodeSnapshotBacking.size;

  @override
  Color? get fillColor => nodeSnapshotBacking.fillColor;

  @override
  Color? get strokeColor => nodeSnapshotBacking.strokeColor;

  @override
  double get strokeWidth => nodeSnapshotBacking.strokeWidth;
}

final class _MaterializedPathNodeSnapshot extends PathNodeSnapshot
    implements NodeSnapshotBackingCarrier {
  _MaterializedPathNodeSnapshot(this.nodeSnapshotBacking)
    : super(id: _placeholderNodeId, svgPathData: _placeholderSvgPathData);

  @override
  final PathNodeSnapshotBacking nodeSnapshotBacking;

  @override
  NodeId get id => nodeSnapshotBacking.id;

  @override
  int get instanceRevision => nodeSnapshotBacking.instanceRevision;

  @override
  Transform2D get transform => nodeSnapshotBacking.transform;

  @override
  double get opacity => nodeSnapshotBacking.opacity;

  @override
  double get hitPadding => nodeSnapshotBacking.hitPadding;

  @override
  bool get isVisible => nodeSnapshotBacking.isVisible;

  @override
  bool get isSelectable => nodeSnapshotBacking.isSelectable;

  @override
  bool get isLocked => nodeSnapshotBacking.isLocked;

  @override
  bool get isDeletable => nodeSnapshotBacking.isDeletable;

  @override
  bool get isTransformable => nodeSnapshotBacking.isTransformable;

  @override
  String get svgPathData => nodeSnapshotBacking.svgPathData;

  @override
  Color? get fillColor => nodeSnapshotBacking.fillColor;

  @override
  Color? get strokeColor => nodeSnapshotBacking.strokeColor;

  @override
  double get strokeWidth => nodeSnapshotBacking.strokeWidth;

  @override
  PathFillRule get fillRule => nodeSnapshotBacking.fillRule;
}

const LayerId _placeholderLayerId = 'layer-materialized-placeholder';
const NodeId _placeholderNodeId = 'node-materialized-placeholder';
const String _placeholderImageId = 'asset:materialized-placeholder';
const String _placeholderText = 'materialized';
const String _placeholderSvgPathData = 'M0 0 L1 1';
const Size _placeholderSize = Size(1, 1);
const Color _placeholderColor = Color(0xFF000000);
const List<Offset> _placeholderStrokePoints = <Offset>[
  Offset.zero,
  Offset(1, 0),
];

CameraSnapshotBacking _cameraSnapshotBackingOf(CameraSnapshot value) {
  return CameraSnapshotBacking(offset: value.offset);
}

BackgroundSnapshotBacking _backgroundSnapshotBackingOf(
  BackgroundSnapshot value,
) {
  return BackgroundSnapshotBacking(
    color: value.color,
    grid: GridSnapshotBacking(
      isEnabled: value.grid.isEnabled,
      cellSize: value.grid.cellSize,
      color: value.grid.color,
    ),
  );
}
