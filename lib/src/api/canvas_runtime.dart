import 'dart:async';

import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_runtime.dart';
import '../contracts/public/canvas_tools.dart';
import '../runtime/runtime_root.dart';

export '../contracts/public/canvas_runtime.dart';

/// Public API v1 declaration for [CanvasRuntime].
// The facade intentionally exposes the complete runtime port set from one
// public entrypoint; splitting it would fragment the consumer contract.
// ignore: coupling-between-object-classes, number-of-methods
final class CanvasRuntime {
  CanvasRuntime({
    CanvasDocument? initialDocument,
    CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
  }) {
    final document = initialDocument ?? CanvasDocument();
    _root = RuntimeRoot(initialDocument: document, config: config);
  }

  late final RuntimeRoot _root;

  CanvasDocument readDocument() => _root.readDocument();
  ValueListenable<CanvasRuntimeState> get state => _root.state;
  CanvasEditPort get edits => _root.edits;
  CanvasSelectionPort get selection => _root.selection;
  CanvasToolPort get tools => throw UnimplementedError();
  CanvasCommandPort get commands => throw UnimplementedError();
  CanvasCameraPort get camera => _root.cameraPort();
  CanvasResourcePort get resources => throw UnimplementedError();
  CanvasPreviewState get preview => throw UnimplementedError();
  Stream<CanvasActionCommitted> get actions => _root.actions;
  Stream<CanvasContextActionRequested> get contextActionRequests =>
      throw UnimplementedError();
  CanvasElementId generateElementId() => _root.generateElementId();
  CanvasLayerId generateLayerId() => _root.generateLayerId();
  CanvasResourceId generateResourceId() => _root.generateResourceId();
  void dispose() {
    _root.dispose();
  }
}
