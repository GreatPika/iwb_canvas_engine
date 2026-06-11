import 'dart:async';

// EditKernel is the public edit lifecycle boundary and now names both
// materialized and sparse accepted commit seams directly so route ownership is
// auditable.
// ignore_for_file: number-of-imports

import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_runtime.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_commit_finalization.dart';
import '../store/store_revision_delta.dart';
import 'commit_applier.dart';
import 'commit_compiler.dart';
import 'commit_plan.dart';
import 'draft_document.dart';
import 'edit_session.dart';

typedef DraftDocumentReader = CanvasDocument Function();
typedef SparseEditFactsReader = SparseEditSessionFacts Function();
typedef SelectedElementIdsReader = Set<CanvasElementId> Function();
typedef CommitInstaller =
    CommitDeliveryResult Function(
      AcceptedCommitDocument document,
      CommitPlan plan,
    );
typedef SparseCommitPreparer =
    PreparedSparseStoreCommit Function(StoreSparseCommit commit);
typedef MaterializedCommitPreparer =
    PreparedMaterializedStoreCommit Function(
      CanvasDocument document,
      StoreRevisionDelta revisionDelta,
    );
typedef DocumentLoadInstaller = void Function(String json);

// EditKernel owns the route handoff between public callbacks, sparse session
// preparation, materialized fallback, and commit delivery; splitting those
// collaborators would hide the all-or-nothing transaction boundary.
// ignore: coupling-between-object-classes
final class EditKernel {
  EditKernel({
    required ResolverMutationGuard mutationGuard,
    required DraftDocumentReader readDocument,
    required SparseEditFactsReader readSparseFacts,
    required SelectedElementIdsReader selectedElementIds,
    required SparseCommitPreparer prepareSparseCommit,
    required MaterializedCommitPreparer prepareMaterializedCommit,
    required CommitInstaller installCommit,
    required CommitApplyResultDelivery deliverApplyResult,
    required DocumentLoadInstaller installLoadedDocument,
  }) : _mutationGuard = mutationGuard,
       _readDocument = readDocument,
       _readSparseFacts = readSparseFacts,
       _selectedElementIds = selectedElementIds,
       _prepareSparseCommit = prepareSparseCommit,
       _prepareMaterializedCommit = prepareMaterializedCommit,
       _installCommit = installCommit,
       _deliverApplyResult = deliverApplyResult,
       _installLoadedDocument = installLoadedDocument;

  final ResolverMutationGuard _mutationGuard;
  final DraftDocumentReader _readDocument;
  final SparseEditFactsReader _readSparseFacts;
  final SelectedElementIdsReader _selectedElementIds;
  final SparseCommitPreparer _prepareSparseCommit;
  final MaterializedCommitPreparer _prepareMaterializedCommit;
  final CommitInstaller _installCommit;
  final CommitApplyResultDelivery _deliverApplyResult;
  final DocumentLoadInstaller _installLoadedDocument;
  late final CanvasEditPort port = _EditKernelPort(this);
  bool _isSessionOpen = false;
  bool get hasOpenSession => _isSessionOpen;

  T edit<T>(T Function(CanvasEdit edit) fn) {
    _mutationGuard.ensureRuntimeMutationAllowed();
    if (_isSessionOpen) {
      throw StateError('CanvasRuntime edit sessions cannot be nested.');
    }

    _isSessionOpen = true;
    final selectedElementIds = _selectedElementIds();
    final session = _openSparseSession(selectedElementIds);

    try {
      final result = fn(session);
      if (result is Future<Object?>) {
        throw StateError(
          'CanvasRuntime edit callbacks must complete synchronously.',
        );
      }
      final accepted = _acceptedCommitFor(session, selectedElementIds);
      if (accepted.plan.hasChanges) {
        final applyResult = _installCommittedDocument(
          accepted.document,
          accepted.plan,
        );
        session.close();
        _isSessionOpen = false;
        _deliverApplyResult(applyResult);
      }

      return result;
    } finally {
      session.close();
      _isSessionOpen = false;
    }
  }

  CommitDeliveryResult prepareInteractionCommit<T>(
    T Function(CanvasEdit edit) fn, {
    CommitPlan Function(CommitPlan plan)? augmentPlan,
  }) {
    _mutationGuard.ensureRuntimeMutationAllowed();
    if (_isSessionOpen) {
      throw StateError('CanvasRuntime edit sessions cannot be nested.');
    }

    _isSessionOpen = true;
    final selectedElementIds = _selectedElementIds();
    final session = _openSparseSession(selectedElementIds);

    try {
      final result = fn(session);
      if (result is Future<Object?>) {
        throw StateError(
          'CanvasRuntime edit callbacks must complete synchronously.',
        );
      }
      final accepted = _acceptedCommitFor(session, selectedElementIds);
      if (accepted.plan.hasChanges) {
        final plan = augmentPlan?.call(accepted.plan) ?? accepted.plan;
        final applyResult = _installCommittedDocument(accepted.document, plan);
        session.close();
        _isSessionOpen = false;

        return applyResult;
      }

      return CommitDeliveryResult(shouldPublishState: false);
    } finally {
      session.close();
      _isSessionOpen = false;
    }
  }

  CommitDeliveryResult prepareInteractionPlan(CommitPlan plan) {
    _mutationGuard.ensureRuntimeMutationAllowed();
    if (_isSessionOpen) {
      throw StateError('CanvasRuntime edit sessions cannot be nested.');
    }
    if (!plan.hasChanges) {
      return CommitDeliveryResult(shouldPublishState: false);
    }

    return _installCommittedDocument(
      plan.revisionDelta.hasChanges
          ? AcceptedMaterializedDocument(
              document: _readDocument(),
              revisionDelta: plan.revisionDelta,
            )
          : const AcceptedUnchangedStoreDocument(),
      plan,
    );
  }

  CommitDeliveryResult _installCommittedDocument(
    AcceptedCommitDocument document,
    CommitPlan plan,
  ) => _installCommit.call(document, plan);

  EditSession _openSparseSession(Set<CanvasElementId> selectedElementIds) {
    return EditSession.sparse(
      facts: _readSparseFacts(),
      promoteDraft: () => DraftDocument(
        _readDocument(),
        selectedElementIds: selectedElementIds,
      ),
      selectedElementIds: selectedElementIds,
    );
  }

  _AcceptedEditCommit _acceptedCommitFor(
    EditSession session,
    Set<CanvasElementId> selectedElementIds,
  ) {
    if (!session.didChange) {
      return _AcceptedEditCommit.empty();
    }
    if (session.hasMaterializedDraft) {
      if (session.didReplaceDraftDocument) {
        return _AcceptedEditCommit(
          document: AcceptedMaterializedDocument(
            document: session.readDraftDocument(),
            revisionDelta: session.revisionDelta,
          ),
          plan: const CommitCompiler().compile(
            revisionDelta: session.revisionDelta,
            touchedSet: session.touchedSet,
          ),
        );
      }
      final prepared = _prepareMaterializedCommit(
        session.readDraftDocument(),
        session.revisionDelta,
      );

      return _acceptedPreparedStoreCommit(
        _AcceptedStoreCommitInput(
          document: AcceptedMaterializedStoreDocument(commit: prepared),
          revisionDelta: prepared.revisionDelta,
          touchedFacts: prepared.touchedFacts,
          selectedElementIds: selectedElementIds,
        ),
      );
    }

    final prepared = _prepareSparseCommit(session.sparseCommit);

    return _acceptedPreparedStoreCommit(
      _AcceptedStoreCommitInput(
        document: AcceptedSparseStoreDocument(commit: prepared),
        revisionDelta: prepared.revisionDelta,
        touchedFacts: prepared.touchedFacts,
        selectedElementIds: selectedElementIds,
      ),
    );
  }
}

final class _AcceptedStoreCommitInput {
  const _AcceptedStoreCommitInput({
    required this.document,
    required this.revisionDelta,
    required this.touchedFacts,
    required this.selectedElementIds,
  });

  final AcceptedCommitDocument document;
  final StoreRevisionDelta revisionDelta;
  final AcceptedStoreTouchedFacts touchedFacts;
  final Set<CanvasElementId> selectedElementIds;
}

_AcceptedEditCommit _acceptedPreparedStoreCommit(
  _AcceptedStoreCommitInput input,
) {
  if (!input.revisionDelta.hasChanges) {
    return _AcceptedEditCommit.empty();
  }

  return _AcceptedEditCommit(
    document: input.document,
    plan: const CommitCompiler().compile(
      revisionDelta: input.revisionDelta,
      touchedSet: _touchedSetForAcceptedFacts(
        input.touchedFacts,
        selectedElementIds: input.selectedElementIds,
      ),
    ),
  );
}

final class _AcceptedEditCommit {
  const _AcceptedEditCommit({required this.document, required this.plan});

  factory _AcceptedEditCommit.empty() {
    return _AcceptedEditCommit(
      document: const AcceptedUnchangedStoreDocument(),
      plan: CommitPlan.empty(),
    );
  }

  final AcceptedCommitDocument document;
  final CommitPlan plan;
}

TouchedSet _touchedSetForAcceptedFacts(
  AcceptedStoreTouchedFacts facts, {
  required Set<CanvasElementId> selectedElementIds,
}) {
  return TouchedSet(
    addedElementIds: facts.addedElementIds,
    removedElementIds: facts.removedElementIds,
    updatedElementIds: facts.updatedElementIds,
    transformedElementIds: facts.transformedElementIds,
    geometryElementIds: facts.geometryElementIds,
    visualElementIds: facts.visualElementIds,
    resourceDescriptorChangedIds: facts.resourceDescriptorChangedIds,
    resourceVisualChangedIds: facts.resourceVisualChangedIds,
    layerIds: facts.layerIds,
    backgroundLayerChanged: facts.backgroundLayerChanged,
    selection: _acceptedTouchesSelection(facts, selectedElementIds),
    persistedCamera: facts.persistedCamera,
    background: facts.background,
    grid: facts.grid,
    palette: facts.palette,
  );
}

bool _acceptedTouchesSelection(
  AcceptedStoreTouchedFacts facts,
  Set<CanvasElementId> selectedElementIds,
) {
  if (selectedElementIds.isEmpty) {
    return false;
  }

  return facts.removedElementIds.any(selectedElementIds.contains) ||
      facts.selectionPruneElementIds.any(selectedElementIds.contains);
}

final class _EditKernelPort implements CanvasEditPort {
  const _EditKernelPort(this.kernel);

  final EditKernel kernel;

  @override
  T edit<T>(T Function(CanvasEdit edit) fn) => kernel.edit(fn);

  @override
  void loadDocumentFromJson(String json) {
    kernel._mutationGuard.ensureRuntimeMutationAllowed();
    if (kernel._isSessionOpen) {
      throw StateError(
        'CanvasRuntime public mutations cannot run inside an active edit callback.',
      );
    }
    kernel._installLoadedDocument(json);
  }
}
