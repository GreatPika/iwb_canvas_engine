import '../api/canvas_document.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef DocumentInstall =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef SelectionEffectInstall = bool Function();

final class CommitApplier {
  const CommitApplier();

  bool apply({
    required CanvasDocument document,
    required CommitPlan plan,
    required DocumentInstall installDocument,
    required SelectionEffectInstall installSelectionEffects,
  }) {
    if (!plan.hasChanges) {
      return false;
    }

    installDocument(document, plan.revisionDelta);
    final didChangeSelection =
        plan.touchedSet.selection && installSelectionEffects();

    return plan.revisionDelta.document || didChangeSelection;
  }
}
