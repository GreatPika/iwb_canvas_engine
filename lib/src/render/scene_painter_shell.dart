import 'dart:ui';

import '../contract/snapshot.dart';
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

  void paint(Canvas canvas, Size size, SceneSnapshot snapshot) {
    final frame = frameOwner.create(size);
    backgroundOwner.paint(canvas, size, snapshot, frame.cameraOffset);
    nodeRenderer.paintNodeLayers(
      canvas: canvas,
      snapshot: snapshot,
      frame: frame,
      resolveNodePaintData: frameOwner.resolveNodePaintData,
    );
    selectionRenderer.drawSceneSelection(canvas, frame);
  }
}
