import '../snapshot.dart';
import 'snapshot_backing.dart';
import 'snapshot_boundary_impl.dart';

SceneSnapshot unsafeMaterializeSceneSnapshot(SceneSnapshotBacking backing) {
  return materializeSceneSnapshotForInternalUse(backing);
}

BackgroundLayerSnapshot unsafeMaterializeBackgroundLayerSnapshot(
  BackgroundLayerSnapshotBacking backing,
) {
  return materializeBackgroundLayerSnapshotForInternalUse(backing);
}

List<ContentLayerSnapshot> unsafeMaterializeContentLayerSnapshotList(
  Iterable<ContentLayerSnapshotBacking> backings,
) {
  return List<ContentLayerSnapshot>.unmodifiable(
    backings.map(unsafeMaterializeContentLayerSnapshot),
  );
}

ContentLayerSnapshot unsafeMaterializeContentLayerSnapshot(
  ContentLayerSnapshotBacking backing,
) {
  return materializeContentLayerSnapshotForInternalUse(backing);
}

CameraSnapshot unsafeMaterializeCameraSnapshot(CameraSnapshotBacking backing) {
  return materializeCameraSnapshotForInternalUse(backing);
}

BackgroundSnapshot unsafeMaterializeBackgroundSnapshot(
  BackgroundSnapshotBacking backing,
) {
  return materializeBackgroundSnapshotForInternalUse(backing);
}

GridSnapshot unsafeMaterializeGridSnapshot(GridSnapshotBacking backing) {
  return materializeGridSnapshotForInternalUse(backing);
}

ScenePaletteSnapshot unsafeMaterializeScenePaletteSnapshot(
  ScenePaletteSnapshotBacking backing,
) {
  return materializeScenePaletteSnapshotForInternalUse(backing);
}

List<NodeSnapshot> unsafeMaterializeNodeSnapshotList(
  Iterable<NodeSnapshotBacking> backings,
) {
  return List<NodeSnapshot>.unmodifiable(
    backings.map(unsafeMaterializeNodeSnapshot),
  );
}

NodeSnapshot unsafeMaterializeNodeSnapshot(NodeSnapshotBacking backing) {
  return switch (backing) {
    ImageNodeSnapshotBacking image => unsafeMaterializeImageNodeSnapshot(image),
    TextNodeSnapshotBacking text => unsafeMaterializeTextNodeSnapshot(text),
    StrokeNodeSnapshotBacking stroke => unsafeMaterializeStrokeNodeSnapshot(
      stroke,
    ),
    LineNodeSnapshotBacking line => unsafeMaterializeLineNodeSnapshot(line),
    RectNodeSnapshotBacking rect => unsafeMaterializeRectNodeSnapshot(rect),
    PathNodeSnapshotBacking path => unsafeMaterializePathNodeSnapshot(path),
  };
}

ImageNodeSnapshot unsafeMaterializeImageNodeSnapshot(
  ImageNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as ImageNodeSnapshot;
}

TextNodeSnapshot unsafeMaterializeTextNodeSnapshot(
  TextNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as TextNodeSnapshot;
}

StrokeNodeSnapshot unsafeMaterializeStrokeNodeSnapshot(
  StrokeNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as StrokeNodeSnapshot;
}

LineNodeSnapshot unsafeMaterializeLineNodeSnapshot(
  LineNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as LineNodeSnapshot;
}

RectNodeSnapshot unsafeMaterializeRectNodeSnapshot(
  RectNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as RectNodeSnapshot;
}

PathNodeSnapshot unsafeMaterializePathNodeSnapshot(
  PathNodeSnapshotBacking backing,
) {
  return materializeNodeSnapshotForInternalUse(backing) as PathNodeSnapshot;
}
