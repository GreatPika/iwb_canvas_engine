import '../core/scene.dart';
import '../contract/snapshot.dart';
import 'scene_from_import_draft.dart';
import 'scene_import_draft_from_snapshot.dart';

Scene sceneImportFromSnapshot(
  SceneSnapshot rawSnapshot, {
  int Function()? nextInstanceRevision,
}) {
  return sceneImportFromDraft(
    sceneImportDraftFromSnapshot(rawSnapshot),
    nextInstanceRevision: nextInstanceRevision,
  );
}
