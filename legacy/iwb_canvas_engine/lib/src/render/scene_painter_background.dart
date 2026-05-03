import 'dart:ui';

import '../contract/snapshot.dart';
import 'cache/scene_static_layer_cache.dart';
import 'scene_grid_renderer.dart';

const _gridRenderer = SceneGridRenderer();

class ScenePainterBackgroundOwner {
  const ScenePainterBackgroundOwner({
    required this.staticLayerCache,
    required this.gridStrokeWidth,
  });

  final SceneStaticLayerCache? staticLayerCache;
  final double gridStrokeWidth;

  void paint(
    Canvas canvas,
    Size size,
    SceneSnapshot snapshot,
    Offset cameraOffset,
  ) {
    final staticLayerCache = this.staticLayerCache;
    if (staticLayerCache != null) {
      staticLayerCache.draw(
        canvas,
        SceneGridRenderRequest(
          grid: snapshot.background.grid,
          size: size,
          cameraOffset: cameraOffset,
          gridStrokeWidth: gridStrokeWidth,
        ),
        backgroundColor: snapshot.background.color,
      );
      return;
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = snapshot.background.color,
    );
    _gridRenderer.draw(
      canvas,
      SceneGridRenderRequest(
        grid: snapshot.background.grid,
        size: size,
        cameraOffset: cameraOffset,
        gridStrokeWidth: gridStrokeWidth,
      ),
    );
  }
}
