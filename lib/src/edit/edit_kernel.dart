import 'dart:async';
import 'dart:ui';

// EditKernel is the public CanvasEdit adapter and must name every DTO that the
// handle accepts; wrapping those imports would make the mutation boundary less
// auditable without reducing coupling.
// ignore_for_file: number-of-imports

import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_element_update.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_resource.dart';
import '../api/canvas_runtime.dart';
import 'commit_plan.dart';
import '../store/store_revision_delta.dart';
import 'draft_document.dart';

typedef RuntimeDisposedReader = bool Function();
typedef DraftDocumentReader = CanvasDocument Function();
typedef SelectedElementIdsReader = Set<CanvasElementId> Function();
typedef DocumentInstaller =
    void Function(CanvasDocument document, CommitPlan plan);

final class EditKernel {
  EditKernel({
    required RuntimeDisposedReader isRuntimeDisposed,
    required DraftDocumentReader readDocument,
    required SelectedElementIdsReader selectedElementIds,
    required DocumentInstaller installDocument,
  }) : _isRuntimeDisposed = isRuntimeDisposed,
       _readDocument = readDocument,
       _selectedElementIds = selectedElementIds,
       _installDocument = installDocument;

  final RuntimeDisposedReader _isRuntimeDisposed;
  final DraftDocumentReader _readDocument;
  final SelectedElementIdsReader _selectedElementIds;
  final DocumentInstaller _installDocument;
  late final CanvasEditPort port = _EditKernelPort(this);
  bool _isSessionOpen = false;

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
        _installDocument(session.readDraftDocument(), plan);
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

// CanvasEdit is intentionally represented by one session handle: the stale
// guard and draft reference must stay uniform across every public entry point.
// ignore: coupling-between-object-classes, number-of-methods
final class EditSession implements CanvasEdit {
  EditSession({required DraftDocument draft}) : _draft = draft;

  final DraftDocument _draft;
  bool _isClosed = false;

  bool get didChange => _draft.didChange;
  StoreRevisionDelta get revisionDelta => _draft.revisionDelta;
  CommitPlan get commitPlan => _draft.commitPlan;

  void close() {
    _isClosed = true;
  }

  @override
  CanvasDocument readDraftDocument() {
    _ensureActive();

    return _draft.readDocument();
  }

  @override
  CanvasDocumentSummary get draftSummary {
    _ensureActive();

    return _draft.summary;
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    _ensureActive();
    return _draft.ensureLayer(id, index: index);
  }

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    _ensureActive();
    return _draft.addElement(element, layerId: layerId, index: index);
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    _ensureActive();
    return _draft.addBackgroundElement(element, index: index);
  }

  @override
  bool updateElement(CanvasElementUpdate update) {
    _ensureActive();
    return _draft.updateElement(update);
  }

  @override
  bool removeElement(CanvasElementId id) {
    _ensureActive();
    return _draft.removeElement(id);
  }

  @override
  bool upsertResource(CanvasResource resource) {
    _ensureActive();
    return _draft.upsertResource(resource);
  }

  @override
  bool removeUnusedResource(CanvasResourceId id) {
    _ensureActive();
    return _draft.removeUnusedResource(id);
  }

  @override
  void setBackgroundColor(Color color) {
    _ensureActive();
    _draft.setBackgroundColor(color);
  }

  @override
  void setGrid(CanvasGrid grid) {
    _ensureActive();
    _draft.setGrid(grid);
  }

  @override
  void setPalette(CanvasPalette palette) {
    _ensureActive();
    _draft.setPalette(palette);
  }

  @override
  void setCameraOffset(Offset offset) {
    _ensureActive();
    _draft.setCameraOffset(offset);
  }

  @override
  CanvasClearResult clearContent({bool removeUnusedResources = false}) {
    _ensureActive();
    return _draft.clearContent(removeUnusedResources: removeUnusedResources);
  }

  @override
  void replaceDraftDocument(CanvasDocument document) {
    _ensureActive();
    throw UnsupportedError(
      'CanvasEdit.replaceDraftDocument is owned by P6 document loading.',
    );
  }

  void _ensureActive() {
    if (_isClosed) {
      throw StateError('CanvasEdit handle is stale.');
    }
  }
}
