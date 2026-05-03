import '../contract/internal/snapshot_fast_path.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import 'scene_import_draft.dart';

SceneImportDraft sceneImportDraftFromSnapshot(SceneSnapshot snapshot) {
  try {
    final admittedSnapshot = admitSceneSnapshotAtBoundary(snapshot);
    return SceneImportDraft.fromBacking(
      sceneSnapshotBackingOf(admittedSnapshot),
    );
  } on UnsupportedBoundarySubtypeAdmissionException catch (error) {
    throw SceneDataException.unsupportedBoundarySubtype(
      boundaryType: error.typeName,
      runtimeType: error.runtimeTypeName,
      source: error,
    );
  }
}
