import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import 'scene_painter_background.dart';
import 'scene_painter_frame.dart';
import 'scene_painter_node_renderer.dart';
import 'scene_painter_selection.dart';

class ScenePainterShell {
  const ScenePainterShell({
    required this.backgroundOwner,
    required this.frameOwner,
    required this.nodeRenderer,
    required this.selectionRenderer,
  });

  final ScenePainterBackgroundOwner backgroundOwner;
  final ScenePainterFrameOwner frameOwner;
  final ScenePainterNodeRenderer nodeRenderer;
  final ScenePainterSelectionRenderer selectionRenderer;

  void paint(Canvas canvas, Size size, SceneViewFrameRead frameRead) {
    final frame = frameOwner.create(size, frameRead);
    backgroundOwner.paint(canvas, size, frameRead.snapshot, frame.cameraOffset);
    nodeRenderer.paintNodeLayers(
      canvas: canvas,
      frame: frame,
      resolveNodePaintData: (node) =>
          frameOwner.resolveNodePaintData(node, frameRead),
    );
    selectionRenderer.drawSceneSelection(canvas, frame);
  }
}
