import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import '../core/text_layout.dart';
import 'cache/scene_text_layout_cache.dart';
import 'render_geometry_cache.dart';
import 'scene_painter_contract.dart';

class ScenePainterVisibilityBudget {
  const ScenePainterVisibilityBudget._({required this.outset});

  factory ScenePainterVisibilityBudget({
    required bool hasSelectedNodes,
    required ScenePainterSelectionStyle selectionStyle,
  }) {
    final haloOutset = hasSelectedNodes
        ? clampNonNegativeFinite(selectionStyle.haloWidth)
        : 0.0;
    return ScenePainterVisibilityBudget._(
      outset: haloOutset > 1.0 ? haloOutset : 1.0,
    );
  }

  final double outset;

  Rect applyTo(Rect rawViewRect) => rawViewRect.inflate(outset);
}

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

  ScenePainterPaintFrame create(Size size, SceneViewFrameRead frameRead) {
    final selectionStyle = ScenePainterSelectionStyle(
      color: selectionColor,
      haloWidth: clampNonNegativeFinite(selectionStrokeWidth),
    );
    final visibilityBudget = ScenePainterVisibilityBudget(
      hasSelectedNodes: frameRead.selectedNodeIds.isNotEmpty,
      selectionStyle: selectionStyle,
    );
    final cameraOffset = sanitizeFiniteOffset(frameRead.cameraOffset);
    final rawViewRect = Rect.fromLTWH(
      cameraOffset.dx,
      cameraOffset.dy,
      size.width,
      size.height,
    );
    final viewRect = visibilityBudget.applyTo(rawViewRect);
    return ScenePainterPaintFrame(
      cameraOffset: cameraOffset,
      viewRect: viewRect,
      paintPlan: renderState.preparePaintPlan(
        frameRead,
        ScenePaintCandidateQuery(
          viewportRect: rawViewRect,
          visibilityRect: viewRect,
        ),
      ),
      selectedIds: frameRead.selectedNodeIds,
      selectionStyle: selectionStyle,
    );
  }

  ScenePainterResolvedNodePaintData resolveNodePaintData(
    NodeSnapshot node,
    SceneViewFrameRead frameRead,
  ) {
    final textLayout = switch (node) {
      TextNodeSnapshot textNode => _resolveTextLayout(textNode),
      _ => null,
    };
    return ScenePainterResolvedNodePaintData(
      node: node,
      previewDelta: _nodePreviewOffset(node.id, frameRead),
      geometry: geometryCache.get(node, resolvedTextLayout: textLayout),
      textLayout: textLayout,
    );
  }

  Offset _nodePreviewOffset(NodeId nodeId, SceneViewFrameRead frameRead) {
    return sanitizeFiniteOffset(frameRead.previewDeltaResolver(nodeId));
  }

  ResolvedTextLayout _resolveTextLayout(TextNodeSnapshot node) {
    final cache = textLayoutCache;
    if (cache != null) {
      return cache.getOrBuild(node: node);
    }
    return TextLayoutRequest.forRenderSnapshot(node).resolve();
  }
}
