import '../contract/snapshot.dart';
import '../contract/scene_structure_validation.dart';
import '../core/scene.dart';
import 'scene_import_draft.dart';
import 'scene_import_draft_from_snapshot.dart';
import 'scene_validation_path_surface.dart';
import 'scene_value_validation.dart';
import 'scene_value_validation_support.dart' as validation_support;

typedef ScenePolicySnapshotFromScene = SceneSnapshot Function(Scene scene);
typedef ScenePolicySceneFromImportDraft =
    Scene Function(SceneImportDraft draft);

abstract final class ScenePolicy {
  static SceneImportDraft validateImportDraft(
    SceneImportDraft rawDraft, {
    SceneValidationPathSurface pathSurface =
        SceneValidationPathSurface.snapshot,
  }) {
    sceneValidateSceneSnapshotBackingStructure(rawDraft.backing);
    return _validateStructurallyValidImportDraft(
      rawDraft,
      pathSurface: pathSurface,
    );
  }

  static SceneSnapshot validateImportSnapshot(SceneSnapshot rawSnapshot) {
    final rawDraft = sceneImportDraftFromSnapshot(rawSnapshot);
    return sceneSnapshotFromValidatedImportDraft(
      validateImportDraft(
        rawDraft,
        pathSurface: SceneValidationPathSurface.snapshot,
      ),
    );
  }

  static Scene validateRuntimeScene(
    Scene rawScene, {
    required ScenePolicySnapshotFromScene snapshotFromScene,
    required ScenePolicySceneFromImportDraft sceneFromImportDraft,
  }) {
    return _validateSceneBoundary(
      rawScene,
      snapshotFromScene: snapshotFromScene,
      sceneFromImportDraft: sceneFromImportDraft,
    );
  }

  static Scene validateEncodeScene(
    Scene scene, {
    required ScenePolicySnapshotFromScene snapshotFromScene,
    required ScenePolicySceneFromImportDraft sceneFromImportDraft,
  }) {
    return _validateSceneBoundary(
      scene,
      snapshotFromScene: snapshotFromScene,
      sceneFromImportDraft: sceneFromImportDraft,
    );
  }

  static Scene _validateSceneBoundary(
    Scene rawScene, {
    required ScenePolicySnapshotFromScene snapshotFromScene,
    required ScenePolicySceneFromImportDraft sceneFromImportDraft,
  }) {
    sceneValidateSceneValues(
      rawScene,
      onError: validation_support.sceneValidationThrowSceneDataException,
      requirePositiveGridCellSize: true,
      requireEnabledMinGridCellSize: true,
    );
    final rawSnapshot = snapshotFromScene(rawScene);
    final rawDraft = sceneImportDraftFromSnapshot(rawSnapshot);
    final canonicalDraft = _validateStructurallyValidImportDraft(
      rawDraft,
      pathSurface: SceneValidationPathSurface.snapshot,
    );
    return sceneFromImportDraft(canonicalDraft);
  }
}

SceneImportDraft _validateStructurallyValidImportDraft(
  SceneImportDraft draft, {
  required SceneValidationPathSurface pathSurface,
}) {
  sceneValidateImportDraftValues(
    draft,
    onError: validation_support.sceneValidationThrowSceneDataException,
    gridPolicy: (
      requirePositiveCellSize: true,
      requireEnabledMinCellSize: true,
    ),
    pathSurface: pathSurface,
  );
  return draft;
}
