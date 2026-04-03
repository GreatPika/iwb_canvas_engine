import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../interactive/scene_controller.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_runtime_host.dart';

@visibleForTesting
SceneRenderCaches debugSceneViewInteractiveRenderCachesOf(
  BuildContext context,
) {
  return debugSceneViewRuntimeHostRenderCachesOf(context);
}

@visibleForTesting
int debugSceneViewInteractiveLiveRawPointerCountOf(BuildContext context) {
  return debugSceneViewRuntimeHostLiveRawPointerCountOf(context);
}

@visibleForTesting
int? debugSceneViewInteractivePendingTapFlushTimestampMsOf(
  BuildContext context,
) {
  return debugSceneViewRuntimeHostPendingTapFlushTimestampMsOf(context);
}

class SceneViewInteractive extends StatelessWidget {
  const SceneViewInteractive({
    required this.controller,
    this.imageResolver,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneController controller;
  final ui.Image? Function(String imageId)? imageResolver;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  Widget build(BuildContext context) {
    return SceneViewRuntimeHost(
      runtime: sceneControllerViewRuntimeOf(controller),
      imageResolver: imageResolver,
      selectionColor: selectionColor,
      selectionStrokeWidth: selectionStrokeWidth,
      gridStrokeWidth: gridStrokeWidth,
    );
  }
}

typedef SceneView = SceneViewInteractive;
