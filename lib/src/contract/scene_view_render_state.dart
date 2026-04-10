import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'scene_render_state.dart';
import 'snapshot.dart';

/// Internal read-side contract shared by the main painter and overlay painter.
abstract interface class SceneViewRenderState implements SceneRenderState {
  int get controllerEpoch;
  Listenable get overlayRepaintListenable;
  Rect? get selectionRect;
  Offset get cameraOffset;
  Offset Function(NodeId nodeId) get previewDeltaResolver;
  Iterable<NodeSnapshot> enumeratePaintCandidates(Rect worldRect);

  bool get hasActiveStrokePreview;
  List<Offset> get activeStrokePreviewPoints;
  double get activeStrokePreviewThickness;
  Color get activeStrokePreviewColor;
  double get activeStrokePreviewOpacity;

  bool get hasActiveLinePreview;
  Offset? get activeLinePreviewStart;
  Offset? get activeLinePreviewEnd;
  double get activeLinePreviewThickness;
  Color get activeLinePreviewColor;
}
