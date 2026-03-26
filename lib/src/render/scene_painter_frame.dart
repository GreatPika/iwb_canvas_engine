import 'dart:ui';

import '../contract/scene_render_state.dart';
import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import 'render_geometry_cache.dart';
import 'scene_painter_contract.dart';

const double scenePainterCullPadding = 1.0;

class ScenePainterFrameOwner {
  const ScenePainterFrameOwner({
    required this.controller,
    required this.geometryCache,
    required this.nodePreviewOffsetResolver,
    required this.selectionRect,
    required this.selectionColor,
    required this.selectionStrokeWidth,
  });

  final SceneRenderState controller;
  final RenderGeometryCache geometryCache;
  final Offset Function(NodeId nodeId)? nodePreviewOffsetResolver;
  final Rect? selectionRect;
  final Color selectionColor;
  final double selectionStrokeWidth;

  ScenePainterPaintFrame create(SceneSnapshot snapshot, Size size) {
    final cameraOffset = sanitizeFiniteOffset(snapshot.camera.offset);
    return ScenePainterPaintFrame(
      cameraOffset: cameraOffset,
      viewRect: Rect.fromLTWH(
        cameraOffset.dx,
        cameraOffset.dy,
        size.width,
        size.height,
      ).inflate(scenePainterCullPadding),
      selectedIds: controller.selectedNodeIds,
      selectionRect: selectionRect,
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
    return sanitizeFiniteOffset(
      nodePreviewOffsetResolver?.call(nodeId) ?? Offset.zero,
    );
  }
}
