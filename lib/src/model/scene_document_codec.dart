import '../core/scene.dart';
import 'scene_builder.dart' as scene_builder;

/// Canonical model codec facade for internal runtime [Scene] documents.
///
/// Downstream non-model code that needs runtime-scene decode or encode
/// canonicalization must import this facade instead of reaching into
/// `scene_builder.dart` or `scene_policy.dart` directly.
Scene sceneDecodeDocumentFromJsonMap(Map<String, Object?> rawJson) {
  return scene_builder.sceneBuildFromJsonMap(rawJson);
}

Scene sceneValidateDocumentForEncode(Scene scene) {
  return scene_builder.sceneValidateCore(scene);
}
