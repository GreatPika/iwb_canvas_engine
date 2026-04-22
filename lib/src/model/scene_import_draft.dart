import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';

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

final class ValidatedSceneImportDraft {
  const ValidatedSceneImportDraft.fromValidated(this._draft);

  final SceneImportDraft _draft;

  SceneSnapshotBacking get backing => _draft.backing;
  List<ContentLayerSnapshotBacking> get layers => _draft.layers;
  BackgroundLayerSnapshotBacking get backgroundLayer => _draft.backgroundLayer;
  CameraSnapshotBacking get camera => _draft.camera;
  BackgroundSnapshotBacking get background => _draft.background;
  ScenePaletteSnapshotBacking get palette => _draft.palette;
}

SceneSnapshot sceneSnapshotFromValidatedImportDraft(
  ValidatedSceneImportDraft draft,
) {
  return sceneSnapshotFromValidatedBacking(draft.backing);
}
