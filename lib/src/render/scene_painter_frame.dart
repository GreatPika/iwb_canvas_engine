import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import '../core/text_layout.dart';
import 'cache/scene_text_layout_cache.dart';
import 'render_geometry_cache.dart';
import 'scene_painter_contract.dart';

const double scenePainterCullPadding = 1.0;

class ScenePainterFrameOwner {
  const ScenePainterFrameOwner({
    required this.renderState,
    required this.textLayoutCache,
    required this.geometryCache,
    required this.selectionColor,
    required this.selectionStrokeWidth,
  });

  final SceneViewRenderState renderState;
  final SceneTextLayoutCache? textLayoutCache;
  final RenderGeometryCache geometryCache;
  final Color selectionColor;
  final double selectionStrokeWidth;

  ScenePainterPaintFrame create(Size size) {
    final cameraOffset = sanitizeFiniteOffset(renderState.cameraOffset);
    final viewRect = Rect.fromLTWH(
      cameraOffset.dx,
      cameraOffset.dy,
      size.width,
      size.height,
    ).inflate(scenePainterCullPadding);
    return ScenePainterPaintFrame(
      cameraOffset: cameraOffset,
      viewRect: viewRect,
      paintCandidates: List<NodeSnapshot>.unmodifiable(
        renderState.enumeratePaintCandidates(viewRect),
      ),
      selectedIds: renderState.selectedNodeIds,
      selectionRect: renderState.selectionRect,
      selectionStyle: ScenePainterSelectionStyle(
        color: selectionColor,
        haloWidth: clampNonNegativeFinite(selectionStrokeWidth),
      ),
    );
  }

  ScenePainterResolvedNodePaintData resolveNodePaintData(NodeSnapshot node) {
    final textLayout = switch (node) {
      TextNodeSnapshot textNode => _resolveTextLayout(textNode),
      _ => null,
    };
    return ScenePainterResolvedNodePaintData(
      node: node,
      previewDelta: _nodePreviewOffset(node.id),
      geometry: geometryCache.get(node, resolvedTextLayout: textLayout),
      textLayout: textLayout,
    );
  }

  Offset _nodePreviewOffset(NodeId nodeId) {
    return sanitizeFiniteOffset(renderState.previewDeltaResolver(nodeId));
  }

  ResolvedTextLayout _resolveTextLayout(TextNodeSnapshot node) {
    final cache = textLayoutCache;
    if (cache != null) {
      return cache.getOrBuild(node: node);
    }
    return TextLayoutRequest.forRenderSnapshot(node).resolve();
  }
}
