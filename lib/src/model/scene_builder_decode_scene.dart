import '../contract/internal/snapshot_fast_path.dart';
import '../contract/scene_structure_validation.dart';
import 'scene_builder_decode_layers.dart';
import 'scene_builder_decode_scene_metadata.dart';
import 'scene_import_draft.dart';

typedef DecodedScenePayload = ({
  CameraSnapshotBacking camera,
  BackgroundSnapshotBacking background,
  ScenePaletteSnapshotBacking palette,
  BackgroundLayerSnapshotBacking? backgroundLayer,
  List<ContentLayerSnapshotBacking> layers,
});

SceneImportDraft sceneBuilderDecodeSceneImportDraftFromJson(
  Map<String, Object?> json,
) {
  sceneBuilderRequireSupportedSchemaVersion(json);
  final payload = _decodeScenePayload(json);
  return SceneImportDraft(
    backgroundLayer: payload.backgroundLayer,
    layers: payload.layers,
    camera: payload.camera,
    background: payload.background,
    palette: payload.palette,
  );
}

DecodedScenePayload _decodeScenePayload(Map<String, Object?> json) {
  var totalNodeCount = 0;

  void consumeNodeBudget(String path) {
    totalNodeCount = sceneConsumeNodeBudget(
      totalNodeCount: totalNodeCount,
      path: path,
    );
  }

  final metadata = sceneBuilderDecodeSceneMetadata(json);
  final layers = sceneBuilderDecodeSceneLayers(
    json,
    onNodeDecoded: consumeNodeBudget,
  );
  return (
    camera: metadata.camera,
    background: metadata.background,
    palette: metadata.palette,
    backgroundLayer: layers.backgroundLayer,
    layers: layers.layers,
  );
}
