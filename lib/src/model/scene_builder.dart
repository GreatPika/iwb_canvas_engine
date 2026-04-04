import '../core/scene.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import 'scene_builder_decode_json.dart';
import 'scene_from_import_draft.dart';
import 'scene_import_draft.dart';
import 'scene_import_draft_from_snapshot.dart';
import 'scene_policy.dart';
import 'scene_snapshot_from_scene.dart';

Scene sceneBuildFromSnapshot(
  SceneSnapshot rawSnapshot, {
  int Function()? nextInstanceRevision,
}) {
  return sceneImportFromDraft(
    sceneImportDraftFromSnapshot(rawSnapshot),
    nextInstanceRevision: nextInstanceRevision,
  );
}

Scene sceneBuildFromJsonMap(Map<String, Object?> rawJson) {
  try {
    final rawDraft = sceneBuilderDecodeImportDraftFromJson(rawJson);
    return sceneImportFromDraft(rawDraft);
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
  final rawDraft = sceneImportDraftFromSnapshot(rawSnapshot);
  return sceneSnapshotFromImportDraft(
    ScenePolicy.validateImportDraft(rawDraft),
  );
}

Scene sceneCanonicalizeAndValidateScene(Scene rawScene) {
  return ScenePolicy.validateRuntimeScene(
    rawScene,
    snapshotFromScene: sceneSnapshotFromScene,
    sceneFromImportDraft: sceneFromImportDraft,
  );
}

Scene sceneValidateCore(Scene scene) {
  return ScenePolicy.validateEncodeScene(
    scene,
    snapshotFromScene: sceneSnapshotFromScene,
    sceneFromImportDraft: sceneFromImportDraft,
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
