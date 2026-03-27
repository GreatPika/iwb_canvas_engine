import '../contract/snapshot.dart';
import 'scene_builder_decode_layers.dart';
import 'scene_builder_decode_scene_metadata.dart';
import 'scene_structural_limits.dart';

typedef DecodedScenePayload = ({
  CameraSnapshot camera,
  BackgroundSnapshot background,
  ScenePaletteSnapshot palette,
  BackgroundLayerSnapshot? backgroundLayer,
  List<ContentLayerSnapshot> layers,
});

SceneSnapshot sceneBuilderDecodeSceneSnapshotFromJson(
  Map<String, Object?> json,
) {
  sceneBuilderRequireSupportedSchemaVersion(json);
  final payload = _decodeScenePayload(json);
  return sceneSnapshotFromValidated(
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
