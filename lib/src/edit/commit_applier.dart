import '../api/canvas_document.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef DocumentInstall =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef SelectionEffectInstall = bool Function();

final class CommitApplyResult {
  CommitApplyResult({
    required this.shouldPublishState,
    Iterable<CommitEffect> effects = const [],
  }) : effects = List.unmodifiable(effects);

  final bool shouldPublishState;
  final List<CommitEffect> effects;
}

final class CommitApplier {
  const CommitApplier();

  CommitApplyResult apply({
    required CanvasDocument document,
    required CommitPlan plan,
    required DocumentInstall installDocument,
    required SelectionEffectInstall installSelectionEffects,
  }) {
    if (!plan.hasChanges) {
      return CommitApplyResult(shouldPublishState: false);
    }

    installDocument(document, plan.revisionDelta);
    final didChangeSelection =
        plan.touchedSet.selection && installSelectionEffects();

    return CommitApplyResult(
      shouldPublishState: plan.revisionDelta.document || didChangeSelection,
      effects: plan.effects,
    );
  }
}
