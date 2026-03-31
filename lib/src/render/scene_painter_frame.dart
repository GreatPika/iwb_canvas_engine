import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import 'render_geometry_cache.dart';
import 'scene_painter_contract.dart';

const double scenePainterCullPadding = 1.0;

class ScenePainterFrameOwner {
  const ScenePainterFrameOwner({
    required this.renderState,
    required this.geometryCache,
    required this.selectionColor,
    required this.selectionStrokeWidth,
  });

  final SceneViewRenderState renderState;
  final RenderGeometryCache geometryCache;
  final Color selectionColor;
  final double selectionStrokeWidth;

  ScenePainterPaintFrame create(Size size) {
    final cameraOffset = sanitizeFiniteOffset(renderState.cameraOffset);
    return ScenePainterPaintFrame(
      cameraOffset: cameraOffset,
      viewRect: Rect.fromLTWH(
        cameraOffset.dx,
        cameraOffset.dy,
        size.width,
        size.height,
      ).inflate(scenePainterCullPadding),
      selectedIds: renderState.selectedNodeIds,
      selectionRect: renderState.selectionRect,
      selectionStyle: ScenePainterSelectionStyle(
        color: selectionColor,
        haloWidth: clampNonNegativeFinite(selectionStrokeWidth),
      ),
    );
  }

  ScenePainterResolvedNodePaintData resolveNodePaintData(NodeSnapshot node) {
    return ScenePainterResolvedNodePaintData(
      node: node,
      previewDelta: _nodePreviewOffset(node.id),
      geometry: geometryCache.get(node),
    );
  }

  Offset _nodePreviewOffset(NodeId nodeId) {
    return sanitizeFiniteOffset(renderState.previewDeltaResolver(nodeId));
  }
}
