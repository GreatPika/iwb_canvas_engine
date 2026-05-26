import '../api/canvas_document.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef DocumentInstall =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef DocumentReplace =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef SelectionEffectInstall = bool Function();

final class CommitDocumentInstallers {
  const CommitDocumentInstallers({
    required this.installDocument,
    required this.replaceDocument,
  });

  final DocumentInstall installDocument;
  final DocumentReplace replaceDocument;
}

final class CommitApplyResult {
  CommitApplyResult({
    required this.shouldPublishState,
    this.replacedDocument = false,
    Iterable<CommitEffect> effects = const [],
  }) : effects = List.unmodifiable(effects);

  final bool shouldPublishState;
  final bool replacedDocument;
  final List<CommitEffect> effects;
}

final class CommitApplier {
  const CommitApplier();

  CommitApplyResult apply({
    required CanvasDocument document,
    required CommitPlan plan,
    required CommitDocumentInstallers documentInstallers,
    required SelectionEffectInstall installSelectionEffects,
  }) {
    if (!plan.hasChanges) {
      return CommitApplyResult(shouldPublishState: false);
    }

    if (plan.documentReplaced) {
      documentInstallers.replaceDocument(document, plan.revisionDelta);
    } else {
      documentInstallers.installDocument(document, plan.revisionDelta);
    }
    final didChangeSelection =
        plan.touchedSet.selection && installSelectionEffects();

    return CommitApplyResult(
      shouldPublishState: plan.revisionDelta.document || didChangeSelection,
      replacedDocument: plan.documentReplaced,
      effects: plan.effects,
    );
  }
}
