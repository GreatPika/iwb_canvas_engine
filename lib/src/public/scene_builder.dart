import '../model/document.dart';
import '../model/scene_builder.dart' as model;
import 'snapshot.dart';

/// Unified scene-import gateway for snapshot/json inputs.
abstract final class SceneBuilder {
  /// Validates and canonicalizes [raw], then returns canonical snapshot.
  static SceneSnapshot buildFromSnapshot(SceneSnapshot raw) {
    final scene = model.sceneBuildFromSnapshot(raw);
    return txnSceneToSnapshot(scene);
  }

  /// Validates and canonicalizes [rawJson], then returns canonical snapshot.
  static SceneSnapshot buildFromJson(Map<String, Object?> rawJson) {
    final scene = model.sceneBuildFromJsonMap(rawJson);
    return txnSceneToSnapshot(scene);
  }
}
