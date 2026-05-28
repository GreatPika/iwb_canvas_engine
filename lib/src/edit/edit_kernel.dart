import 'dart:async';

import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_runtime.dart';
import 'commit_plan.dart';
import 'draft_document.dart';
import 'edit_session.dart';

typedef DraftDocumentReader = CanvasDocument Function();
typedef SelectedElementIdsReader = Set<CanvasElementId> Function();
typedef CommitInstaller =
    CommitDeliveryResult Function(CanvasDocument document, CommitPlan plan);
typedef DocumentLoadInstaller = void Function(CanvasDocument document);

final class EditKernel {
  EditKernel({
    required ResolverMutationGuard mutationGuard,
    required DraftDocumentReader readDocument,
    required SelectedElementIdsReader selectedElementIds,
    required CommitInstaller installCommit,
    required CommitApplyResultDelivery deliverApplyResult,
    required DocumentLoadInstaller installLoadedDocument,
  }) : _mutationGuard = mutationGuard,
       _readDocument = readDocument,
       _selectedElementIds = selectedElementIds,
       _installCommit = installCommit,
       _deliverApplyResult = deliverApplyResult,
       _installLoadedDocument = installLoadedDocument;

  final ResolverMutationGuard _mutationGuard;
  final DraftDocumentReader _readDocument;
  final SelectedElementIdsReader _selectedElementIds;
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
    final session = EditSession(
      draft: DraftDocument(
        _readDocument(),
        selectedElementIds: _selectedElementIds(),
      ),
    );

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
          session.readDraftDocument(),
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

  void loadDocument(CanvasDocument document) {
    _mutationGuard.ensureRuntimeMutationAllowed();
    if (_isSessionOpen) {
      throw StateError(
        'CanvasRuntime public mutations cannot run inside an active edit callback.',
      );
    }
    _installLoadedDocument(document);
  }

  CommitDeliveryResult _installCommittedDocument(
    CanvasDocument document,
    CommitPlan plan,
  ) => _installCommit.call(document, plan);
}

final class _EditKernelPort implements CanvasEditPort {
  const _EditKernelPort(this.kernel);

  final EditKernel kernel;

  @override
  T edit<T>(T Function(CanvasEdit edit) fn) => kernel.edit(fn);

  @override
  void loadDocument(CanvasDocument document) {
    kernel.loadDocument(document);
  }
}
