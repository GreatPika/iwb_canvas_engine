import 'dart:ui';

import '../snapshot.dart';
import '../transform2d.dart';
import 'snapshot_backing.dart';

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

SceneSnapshotBacking sceneSnapshotBackingOf(SceneSnapshot snapshot) {
  try {
    return (snapshot as SceneSnapshotBackingCarrier).sceneSnapshotBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _sceneSnapshotBackingCache[snapshot];
  if (cached != null) {
    return cached;
  }
  if (snapshot.runtimeType != SceneSnapshot) {
    throw StateError(
      'Unsupported SceneSnapshot subtype: ${snapshot.runtimeType}',
    );
  }
  final backing = SceneSnapshotBacking(
    layers: snapshot.layers
        .map(contentLayerSnapshotBackingOf)
        .toList(growable: false),
    backgroundLayer: backgroundLayerSnapshotBackingOf(snapshot.backgroundLayer),
    camera: _cameraSnapshotBackingOf(snapshot.camera),
    background: _backgroundSnapshotBackingOf(snapshot.background),
    palette: scenePaletteSnapshotBackingOf(snapshot.palette),
  );
  _sceneSnapshotBackingCache[snapshot] = backing;
  return backing;
}

BackgroundLayerSnapshotBacking backgroundLayerSnapshotBackingOf(
  BackgroundLayerSnapshot layer,
) {
  try {
    return (layer as BackgroundLayerSnapshotBackingCarrier)
        .backgroundLayerSnapshotBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _backgroundLayerBackingCache[layer];
  if (cached != null) {
    return cached;
  }
  if (layer.runtimeType != BackgroundLayerSnapshot) {
    throw StateError(
      'Unsupported BackgroundLayerSnapshot subtype: ${layer.runtimeType}',
    );
  }
  final backing = BackgroundLayerSnapshotBacking(
    nodes: layer.nodes.map(nodeSnapshotBackingOf).toList(growable: false),
  );
  _backgroundLayerBackingCache[layer] = backing;
  return backing;
}

ContentLayerSnapshotBacking contentLayerSnapshotBackingOf(
  ContentLayerSnapshot layer,
) {
  try {
    return (layer as ContentLayerSnapshotBackingCarrier)
        .contentLayerSnapshotBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _contentLayerBackingCache[layer];
  if (cached != null) {
    return cached;
  }
  if (layer.runtimeType != ContentLayerSnapshot) {
    throw StateError(
      'Unsupported ContentLayerSnapshot subtype: ${layer.runtimeType}',
    );
  }
  final backing = ContentLayerSnapshotBacking(
    id: layer.id,
    nodes: layer.nodes.map(nodeSnapshotBackingOf).toList(growable: false),
  );
  _contentLayerBackingCache[layer] = backing;
  return backing;
}

ScenePaletteSnapshotBacking scenePaletteSnapshotBackingOf(
  ScenePaletteSnapshot palette,
) {
  try {
    return (palette as ScenePaletteSnapshotBackingCarrier)
        .scenePaletteSnapshotBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _paletteBackingCache[palette];
  if (cached != null) {
    return cached;
  }
  if (palette.runtimeType != ScenePaletteSnapshot) {
    throw StateError(
      'Unsupported ScenePaletteSnapshot subtype: ${palette.runtimeType}',
    );
  }
  final backing = ScenePaletteSnapshotBacking(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
  );
  _paletteBackingCache[palette] = backing;
  return backing;
}

NodeSnapshotBacking nodeSnapshotBackingOf(NodeSnapshot snapshot) {
  try {
    return (snapshot as NodeSnapshotBackingCarrier).nodeSnapshotBacking;
  } on TypeError {
    // Fall through to the public-field reconstruction path.
  }
  final cached = _nodeSnapshotBackingCache[snapshot];
  if (cached != null) {
    return cached;
  }
  final backing = _publicNodeSnapshotBackingOf(snapshot);
  _nodeSnapshotBackingCache[snapshot] = backing;
  return backing;
}

NodeSnapshotBacking _publicNodeSnapshotBackingOf(NodeSnapshot snapshot) {
  if (snapshot.runtimeType == ImageNodeSnapshot) {
    final image = snapshot as ImageNodeSnapshot;
    return ImageNodeSnapshotBacking(
      id: image.id,
      instanceRevision: image.instanceRevision,
      imageId: image.imageId,
      size: image.size,
      naturalSize: image.naturalSize,
      transform: image.transform,
      opacity: image.opacity,
      hitPadding: image.hitPadding,
      isVisible: image.isVisible,
      isSelectable: image.isSelectable,
      isLocked: image.isLocked,
      isDeletable: image.isDeletable,
      isTransformable: image.isTransformable,
    );
  }
  if (snapshot.runtimeType == TextNodeSnapshot) {
    final text = snapshot as TextNodeSnapshot;
    return TextNodeSnapshotBacking(
      id: text.id,
      instanceRevision: text.instanceRevision,
      text: text.text,
      size: text.size,
      fontSize: text.fontSize,
      color: text.color,
      align: text.align,
      textDirection: text.textDirection,
      isBold: text.isBold,
      isItalic: text.isItalic,
      isUnderline: text.isUnderline,
      fontFamily: text.fontFamily,
      maxWidth: text.maxWidth,
      lineHeight: text.lineHeight,
      transform: text.transform,
      opacity: text.opacity,
      hitPadding: text.hitPadding,
      isVisible: text.isVisible,
      isSelectable: text.isSelectable,
      isLocked: text.isLocked,
      isDeletable: text.isDeletable,
      isTransformable: text.isTransformable,
    );
  }
  if (snapshot.runtimeType == StrokeNodeSnapshot) {
    final stroke = snapshot as StrokeNodeSnapshot;
    return StrokeNodeSnapshotBacking(
      id: stroke.id,
      instanceRevision: stroke.instanceRevision,
      points: stroke.points,
      pointsRevision: stroke.pointsRevision,
      thickness: stroke.thickness,
      color: stroke.color,
      transform: stroke.transform,
      opacity: stroke.opacity,
      hitPadding: stroke.hitPadding,
      isVisible: stroke.isVisible,
      isSelectable: stroke.isSelectable,
      isLocked: stroke.isLocked,
      isDeletable: stroke.isDeletable,
      isTransformable: stroke.isTransformable,
    );
  }
  if (snapshot.runtimeType == LineNodeSnapshot) {
    final line = snapshot as LineNodeSnapshot;
    return LineNodeSnapshotBacking(
      id: line.id,
      instanceRevision: line.instanceRevision,
      start: line.start,
      end: line.end,
      thickness: line.thickness,
      color: line.color,
      transform: line.transform,
      opacity: line.opacity,
      hitPadding: line.hitPadding,
      isVisible: line.isVisible,
      isSelectable: line.isSelectable,
      isLocked: line.isLocked,
      isDeletable: line.isDeletable,
      isTransformable: line.isTransformable,
    );
  }
  if (snapshot.runtimeType == RectNodeSnapshot) {
    final rect = snapshot as RectNodeSnapshot;
    return RectNodeSnapshotBacking(
      id: rect.id,
      instanceRevision: rect.instanceRevision,
      size: rect.size,
      fillColor: rect.fillColor,
      strokeColor: rect.strokeColor,
      strokeWidth: rect.strokeWidth,
      transform: rect.transform,
      opacity: rect.opacity,
      hitPadding: rect.hitPadding,
      isVisible: rect.isVisible,
      isSelectable: rect.isSelectable,
      isLocked: rect.isLocked,
      isDeletable: rect.isDeletable,
      isTransformable: rect.isTransformable,
    );
  }
  if (snapshot.runtimeType == PathNodeSnapshot) {
    final path = snapshot as PathNodeSnapshot;
    return PathNodeSnapshotBacking(
      id: path.id,
      instanceRevision: path.instanceRevision,
      svgPathData: path.svgPathData,
      fillColor: path.fillColor,
      strokeColor: path.strokeColor,
      strokeWidth: path.strokeWidth,
      fillRule: path.fillRule,
      transform: path.transform,
      opacity: path.opacity,
      hitPadding: path.hitPadding,
      isVisible: path.isVisible,
      isSelectable: path.isSelectable,
      isLocked: path.isLocked,
      isDeletable: path.isDeletable,
      isTransformable: path.isTransformable,
    );
  }
  throw StateError('Unsupported NodeSnapshot subtype: ${snapshot.runtimeType}');
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
        size: _placeholderSize,
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
  Size get size => nodeSnapshotBacking.size;

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
