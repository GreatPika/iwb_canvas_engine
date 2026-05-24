import 'dart:async';
import 'dart:ui';

import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_element_update.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_resource.dart';
import '../api/canvas_runtime.dart';

typedef RuntimeDisposedReader = bool Function();
typedef DraftDocumentReader = CanvasDocument Function();
typedef DraftSummaryReader = CanvasDocumentSummary Function();

final class EditKernel {
  EditKernel({
    required RuntimeDisposedReader isRuntimeDisposed,
    required DraftDocumentReader readDocument,
    required DraftSummaryReader readSummary,
  }) : _isRuntimeDisposed = isRuntimeDisposed,
       _readDocument = readDocument,
       _readSummary = readSummary;

  final RuntimeDisposedReader _isRuntimeDisposed;
  final DraftDocumentReader _readDocument;
  final DraftSummaryReader _readSummary;
  late final CanvasEditPort port = _EditKernelPort(this);
  bool _isSessionOpen = false;

  T edit<T>(T Function(CanvasEdit edit) fn) {
    _ensureRuntimeActive();
    if (_isSessionOpen) {
      throw StateError('CanvasRuntime edit sessions cannot be nested.');
    }

    _isSessionOpen = true;
    final session = EditSession(
      readDocument: _readDocument,
      readSummary: _readSummary,
    );

    try {
      final result = fn(session);
      if (result is Future<Object?>) {
        throw StateError(
          'CanvasRuntime edit callbacks must complete synchronously.',
        );
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
// guard must be uniform across every public handle entry point.
// ignore: number-of-methods
final class EditSession implements CanvasEdit {
  EditSession({
    required DraftDocumentReader readDocument,
    required DraftSummaryReader readSummary,
  }) : _readDocument = readDocument,
       _readSummary = readSummary;

  final DraftDocumentReader _readDocument;
  final DraftSummaryReader _readSummary;
  bool _isClosed = false;

  void close() {
    _isClosed = true;
  }

  @override
  CanvasDocument readDraftDocument() {
    _ensureActive();

    return _readDocument();
  }

  @override
  CanvasDocumentSummary get draftSummary {
    _ensureActive();

    return _readSummary();
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  bool updateElement(CanvasElementUpdate update) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  bool removeElement(CanvasElementId id) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  bool upsertResource(CanvasResource resource) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  bool removeUnusedResource(CanvasResourceId id) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  void setBackgroundColor(Color color) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  void setGrid(CanvasGrid grid) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  void setPalette(CanvasPalette palette) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  void setCameraOffset(Offset offset) {
    _ensureActive();
    _rejectDocumentMutation();
  }

  @override
  CanvasClearResult clearContent({bool removeUnusedResources = false}) {
    _ensureActive();
    _rejectDocumentMutation();
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

  Never _rejectDocumentMutation() {
    throw UnsupportedError(
      'CanvasEdit document mutations are owned by later P5 edit units.',
    );
  }
}
