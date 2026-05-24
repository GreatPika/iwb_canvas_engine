import 'dart:async';

import '../api/canvas_document.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_runtime.dart';
import 'commit_applier.dart';
import 'commit_plan.dart';
import 'draft_document.dart';
import 'edit_session.dart';

typedef RuntimeDisposedReader = bool Function();
typedef DraftDocumentReader = CanvasDocument Function();
typedef SelectedElementIdsReader = Set<CanvasElementId> Function();
typedef DocumentInstaller =
    CommitApplyResult Function(CanvasDocument document, CommitPlan plan);
typedef CommitApplyResultDelivery = void Function(CommitApplyResult result);

final class EditKernel {
  EditKernel({
    required RuntimeDisposedReader isRuntimeDisposed,
    required DraftDocumentReader readDocument,
    required SelectedElementIdsReader selectedElementIds,
    required DocumentInstaller installDocument,
    required CommitApplyResultDelivery deliverApplyResult,
  }) : _isRuntimeDisposed = isRuntimeDisposed,
       _readDocument = readDocument,
       _selectedElementIds = selectedElementIds,
       _installDocument = installDocument,
       _deliverApplyResult = deliverApplyResult;

  final RuntimeDisposedReader _isRuntimeDisposed;
  final DraftDocumentReader _readDocument;
  final SelectedElementIdsReader _selectedElementIds;
  final DocumentInstaller _installDocument;
  final CommitApplyResultDelivery _deliverApplyResult;
  late final CanvasEditPort port = _EditKernelPort(this);
  bool _isSessionOpen = false;
  bool get hasOpenSession => _isSessionOpen;

  T edit<T>(T Function(CanvasEdit edit) fn) {
    _ensureRuntimeActive();
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

  void loadDocument(CanvasDocument _) {
    _ensureRuntimeActive();
    throw UnsupportedError(
      'CanvasEditPort.loadDocument is owned by P6 document loading.',
    );
  }

  void _ensureRuntimeActive() {
    if (_isRuntimeDisposed()) {
      throw StateError('CanvasRuntime is disposed.');
    }
  }

  CommitApplyResult _installCommittedDocument(
    CanvasDocument document,
    CommitPlan plan,
  ) => _installDocument.call(document, plan);
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
