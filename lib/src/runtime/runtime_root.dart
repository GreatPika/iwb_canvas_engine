import 'package:flutter/foundation.dart';

import '../api/canvas_document.dart';
import '../api/canvas_runtime.dart';
import 'runtime_config.dart';

final class RuntimeRoot {
  RuntimeRoot({
    required CanvasDocument initialDocument,
    required CanvasRuntimeConfig config,
  }) : config = RuntimeConfig.from(config),
       _state = ValueNotifier<CanvasRuntimeState>(
         _initialRuntimeState(initialDocument),
       );

  final RuntimeConfig config;
  final ValueNotifier<CanvasRuntimeState> _state;
  bool _isDisposed = false;

  ValueListenable<CanvasRuntimeState> get state => _state;
  bool get isDisposed => _isDisposed;

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _state.dispose();
  }
}

CanvasRuntimeState _initialRuntimeState(CanvasDocument document) {
  final summary = _documentSummary(document);

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
      elementCount: summary.elementCount,
      layerCount: summary.layerCount,
      resourceCount: summary.resourceCount,
      selectedCount: 0,
    ),
  );
}

CanvasDocumentSummary _documentSummary(CanvasDocument document) {
  return CanvasDocumentSummary(
    elementCount:
        document.backgroundElements.length +
        document.layers.fold<int>(
          0,
          (count, layer) => count + layer.elements.length,
        ),
    layerCount: document.layers.length,
    resourceCount: document.resources.length,
  );
}
