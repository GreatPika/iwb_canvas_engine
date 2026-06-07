import 'dart:async';

// EditKernel is the public edit lifecycle boundary and now names both
// materialized and sparse accepted commit seams directly so route ownership is
// auditable.
// ignore_for_file: number-of-imports

import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_runtime.dart';
import '../store/sparse_store_commit.dart';
import 'commit_applier.dart';
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
    required CommitInstaller installCommit,
    required CommitApplyResultDelivery deliverApplyResult,
    required DocumentLoadInstaller installLoadedDocument,
  }) : _mutationGuard = mutationGuard,
       _readDocument = readDocument,
       _readSparseFacts = readSparseFacts,
       _selectedElementIds = selectedElementIds,
       _prepareSparseCommit = prepareSparseCommit,
       _installCommit = installCommit,
       _deliverApplyResult = deliverApplyResult,
       _installLoadedDocument = installLoadedDocument;

  final ResolverMutationGuard _mutationGuard;
  final DraftDocumentReader _readDocument;
  final SparseEditFactsReader _readSparseFacts;
  final SelectedElementIdsReader _selectedElementIds;
  final SparseCommitPreparer _prepareSparseCommit;
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
      final plan = session.commitPlan;
      if (plan.hasChanges) {
        final applyResult = _installCommittedDocument(
          _acceptedDocumentFor(session),
          plan,
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
      var plan = session.commitPlan;
      if (plan.hasChanges) {
        plan = augmentPlan?.call(plan) ?? plan;
        final applyResult = _installCommittedDocument(
          _acceptedDocumentFor(session),
          plan,
        );
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

  AcceptedCommitDocument _acceptedDocumentFor(EditSession session) {
    if (session.hasMaterializedDraft) {
      return AcceptedMaterializedDocument(
        document: session.readDraftDocument(),
        revisionDelta: session.revisionDelta,
      );
    }

    return AcceptedSparseStoreDocument(
      commit: _prepareSparseCommit(session.sparseCommit),
    );
  }
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
