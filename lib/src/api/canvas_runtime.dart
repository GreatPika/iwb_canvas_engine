// The public runtime facade imports every public port plus its internal root
// and frame bridge so construction/disposal remain auditable in one file.
// ignore_for_file: number-of-imports

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_runtime.dart';
import '../contracts/public/canvas_text_editing.dart';
import '../contracts/public/canvas_tools.dart';
import '../runtime/runtime_root.dart';
import 'canvas_runtime_frame_bridge.dart';
import 'canvas_runtime_surface_bridge.dart';

export '../contracts/public/canvas_runtime.dart';
export '../contracts/public/canvas_deletion.dart';

/// Public API v1 declaration for [CanvasRuntime].
// The facade intentionally exposes the complete runtime port set from one
// public entrypoint; splitting it would fragment the consumer contract.
// ignore: coupling-between-object-classes, number-of-methods
final class CanvasRuntime {
  CanvasRuntime({required CanvasRuntimeConfig config}) {
    _root = RuntimeRoot(config: config);
    attachCanvasRuntimeFrameRoot(this, _root);
    attachCanvasRuntimeSurfacePort(this, _root);
  }

  late final RuntimeRoot _root;

  CanvasDocument readDocument() => _root.readDocument();
  CanvasAppearance readAppearance() => _root.readAppearance();
  ValueListenable<CanvasRuntimeState> get state => _root.state;
  CanvasEditPort get edits => _root.edits;
  CanvasSelectionPort get selection => _root.selection;
  CanvasToolPort get tools => _root.toolPort();
  CanvasCommandPort get commands => _root.commandPort();
  CanvasCameraPort get camera => _root.cameraPort();
  CanvasResourcePort get resources => _root.resources;
  CanvasTextEditingPort get textEditing => _root.textEditing;
  CanvasPreviewState get preview => _root.preview;
  Stream<CanvasActionCommitted> get actions => _root.actions;
  Stream<CanvasContextActionRequested> get contextActionRequests =>
      _root.contextActionRequestStream();
  CanvasElementId generateElementId() => _root.generateElementId();
  CanvasLayerId generateLayerId() => _root.generateLayerId();
  CanvasResourceId generateResourceId() => _root.generateResourceId();
  void dispose() {
    _root.dispose();
    detachCanvasRuntimeSurfacePort(this);
    detachCanvasRuntimeFrameRoot(this);
  }
}
