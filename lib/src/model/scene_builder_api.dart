import 'document.dart';
import 'scene_builder.dart' as model;
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';

/// Unified scene-import gateway for snapshot/json inputs.
abstract final class SceneBuilder {
  /// Validates and canonicalizes [raw], then returns a canonical snapshot.
  ///
  /// Throws [SceneDataException] when [raw] violates the public scene boundary
  /// contract.
  static SceneSnapshot buildFromSnapshot(SceneSnapshot raw) {
    final scene = model.sceneBuildFromSnapshot(raw);
    return txnSceneToSnapshot(scene);
  }

  /// Validates and canonicalizes [rawJson], then returns a canonical snapshot.
  ///
  /// Throws [SceneDataException] when [rawJson] is malformed, violates schema
  /// requirements, or fails import validation.
  static SceneSnapshot buildFromJson(Map<String, dynamic> rawJson) {
    final scene = model.sceneBuildFromJsonMap(
      Map<String, Object?>.from(rawJson),
    );
    return txnSceneToSnapshot(scene);
  }
}
