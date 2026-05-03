import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import '../core/text_layout.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'cache/scene_text_layout_cache.dart';
import 'render_geometry_cache.dart';
import 'scene_painter_contract.dart';
import 'scene_painter_shared.dart';

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
    required this.strokePathCache,
    required this.geometryCache,
    required this.selectionColor,
    required this.selectionStrokeWidth,
  });

  final SceneViewMainSceneRenderRead renderState;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final RenderGeometryCache geometryCache;
  final Color selectionColor;
  final double selectionStrokeWidth;

  ScenePainterPaintFrame create(Size size, SceneViewFrameRead frameRead) {
    return ScenePainterPaintFrame.fromPrepared(createPrepared(size, frameRead));
  }

  ScenePainterPreparedFrame createPrepared(
    Size size,
    SceneViewFrameRead frameRead,
  ) {
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
    return ScenePainterPreparedFrame(
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
    final strokePath = switch (node) {
      StrokeNodeSnapshot strokeNode when strokeNode.points.length > 1 =>
        scenePainterResolveStrokePath(strokeNode, strokePathCache),
      _ => null,
    };
    return ScenePainterResolvedNodePaintData(
      node: node,
      previewDelta: _nodePreviewOffset(node.id, frameRead),
      geometry: geometryCache.get(node, resolvedTextLayout: textLayout),
      textLayout: textLayout,
      strokePath: strokePath,
    );
  }

  Offset _nodePreviewOffset(NodeId nodeId, SceneViewFrameRead frameRead) {
    return frameRead.preview.deltaForNode(nodeId);
  }

  ResolvedTextLayout _resolveTextLayout(TextNodeSnapshot node) {
    final cache = textLayoutCache;
    if (cache != null) {
      return cache.getOrBuild(node: node);
    }
    return TextLayoutRequest.forRenderSnapshot(node).resolve();
  }
}
