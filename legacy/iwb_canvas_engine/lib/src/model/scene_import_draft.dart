import '../contract/internal/snapshot_fast_path.dart';

final class SceneImportDraft {
  SceneImportDraft({
    List<ContentLayerSnapshotBacking>? layers,
    BackgroundLayerSnapshotBacking? backgroundLayer,
    CameraSnapshotBacking? camera,
    BackgroundSnapshotBacking? background,
    ScenePaletteSnapshotBacking? palette,
  }) : this.fromBacking(
         sceneSnapshotBackingFromValidated(
           layers: layers,
           backgroundLayer: backgroundLayer,
           camera: camera,
           background: background,
           palette: palette,
         ),
       );

  const SceneImportDraft.fromBacking(this.backing);

  final SceneSnapshotBacking backing;

  List<ContentLayerSnapshotBacking> get layers => backing.layers;
  BackgroundLayerSnapshotBacking get backgroundLayer => backing.backgroundLayer;
  CameraSnapshotBacking get camera => backing.camera;
  BackgroundSnapshotBacking get background => backing.background;
  ScenePaletteSnapshotBacking get palette => backing.palette;
}
