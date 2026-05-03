import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import 'scene_painter_background.dart';
import 'scene_painter_contract.dart';
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

  ScenePainterPreparedFrame prepareFrame(
    Size size,
    SceneViewFrameRead frameRead,
  ) {
    return frameOwner.createPrepared(size, frameRead);
  }

  void paint(Canvas canvas, Size size, SceneViewFrameRead frameRead) {
    paintPrepared(canvas, size, frameRead, prepareFrame(size, frameRead));
  }

  void paintPrepared(
    Canvas canvas,
    Size size,
    SceneViewFrameRead frameRead,
    ScenePainterPreparedFrame preparedFrame,
  ) {
    final frame = ScenePainterPaintFrame.fromPrepared(preparedFrame);
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
