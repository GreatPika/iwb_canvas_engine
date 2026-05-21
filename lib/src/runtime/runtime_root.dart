import 'package:flutter/foundation.dart';

import '../api/canvas_document.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_runtime.dart';
import '../store/document_store_kernel.dart';
import 'runtime_config.dart';

// RuntimeRoot keeps lifecycle, public state, read projection, and id-generation
// facade routing together because it is the runtime composition root; splitting
// those pass-throughs would hide ownership.
// ignore: metrics
final class RuntimeRoot {
  RuntimeRoot({
    required CanvasDocument initialDocument,
    required CanvasRuntimeConfig config,
  }) : this._(
         store: DocumentStoreKernel(initialDocument),
         config: RuntimeConfig.from(config),
       );

  RuntimeRoot._({required DocumentStoreKernel store, required this.config})
    : _store = store,
      _state = ValueNotifier<CanvasRuntimeState>(_initialRuntimeState(store));

  final RuntimeConfig config;
  final DocumentStoreKernel _store;
  final ValueNotifier<CanvasRuntimeState> _state;
  bool _isDisposed = false;

  ValueListenable<CanvasRuntimeState> get state => _state;
  bool get isDisposed => _isDisposed;
  int get projectionBuildCount => _store.projectionBuildCount;

  CanvasDocument readDocument() => _store.readDocument();
  CanvasElementId generateElementId() {
    _ensureNotDisposed();

    return _store.generateElementId();
  }

  CanvasLayerId generateLayerId() {
    _ensureNotDisposed();

    return _store.generateLayerId();
  }

  CanvasResourceId generateResourceId() {
    _ensureNotDisposed();

    return _store.generateResourceId();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _state.dispose();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('CanvasRuntime is disposed.');
    }
  }
}

CanvasRuntimeState _initialRuntimeState(DocumentStoreKernel store) {
  return CanvasRuntimeState(
    revisions: const CanvasRuntimeRevisions(
      document: 0,
      selection: 0,
      preview: 0,
      viewCamera: 0,
      resourceVisual: 0,
      interaction: 0,
      epoch: 0,
    ),
    summary: CanvasRuntimeSummary(
      elementCount: store.documentSummary.elementCount,
      layerCount: store.documentSummary.layerCount,
      resourceCount: store.documentSummary.resourceCount,
      selectedCount: 0,
    ),
  );
}
