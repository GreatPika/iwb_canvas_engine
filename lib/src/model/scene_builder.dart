import '../core/scene.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import 'scene_builder_decode_json.dart';
import 'scene_policy.dart';
import 'scene_from_snapshot.dart';
import 'scene_snapshot_from_scene.dart';

Scene sceneBuildFromSnapshot(
  SceneSnapshot rawSnapshot, {
  int Function()? nextInstanceRevision,
}) {
  return sceneImportFromSnapshot(
    rawSnapshot,
    nextInstanceRevision: nextInstanceRevision,
  );
}

Scene sceneBuildFromJsonMap(Map<String, Object?> rawJson) {
  try {
    final rawSnapshot = sceneBuilderDecodeSnapshotFromJson(rawJson);
    return sceneBuildFromSnapshot(rawSnapshot);
  } on SceneDataException {
    rethrow;
  } catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  }
}

Scene sceneBuildFromDynamicJsonMap(Map<String, dynamic> rawJson) {
  return _guardBuild(rawJson, sceneBuildFromJsonMap);
}

SceneSnapshot sceneCanonicalizeAndValidateSnapshot(SceneSnapshot rawSnapshot) {
  return ScenePolicy.validateImportSnapshot(rawSnapshot);
}

Scene sceneCanonicalizeAndValidateScene(Scene rawScene) {
  return ScenePolicy.validateRuntimeScene(
    rawScene,
    snapshotFromScene: sceneSnapshotFromScene,
    sceneFromSnapshot: sceneFromSnapshot,
  );
}

Scene sceneValidateCore(Scene scene) {
  return ScenePolicy.validateEncodeScene(
    scene,
    snapshotFromScene: sceneSnapshotFromScene,
    sceneFromSnapshot: sceneFromSnapshot,
  );
}

T _guardBuild<T>(
  Map<String, dynamic> rawJson,
  T Function(Map<String, Object?> raw) build,
) {
  try {
    return build(Map<String, Object?>.from(rawJson));
  } on SceneDataException {
    rethrow;
  } on FormatException catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  } catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  }
}
