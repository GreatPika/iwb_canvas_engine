import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import 'scene_import_draft.dart';

SceneImportDraft sceneImportDraftFromSnapshot(SceneSnapshot snapshot) {
  return SceneImportDraft.fromBacking(sceneSnapshotBackingOf(snapshot));
}
