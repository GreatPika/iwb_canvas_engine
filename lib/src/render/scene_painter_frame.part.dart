part of 'scene_painter.dart';

class _ScenePainterFrameOwner {
  const _ScenePainterFrameOwner({
    required this.controller,
    required this.geometryCache,
    required this.nodePreviewOffsetResolver,
    required this.selectionRect,
    required this.selectionColor,
    required this.selectionStrokeWidth,
  });

  final SceneRenderState controller;
  final RenderGeometryCache geometryCache;
  final NodePreviewOffsetResolver? nodePreviewOffsetResolver;
  final Rect? selectionRect;
  final Color selectionColor;
  final double selectionStrokeWidth;

  _PaintFrame create(SceneSnapshot snapshot, Size size) {
    final cameraOffset = sanitizeFiniteOffset(snapshot.camera.offset);
    return _PaintFrame(
      cameraOffset: cameraOffset,
      viewRect: Rect.fromLTWH(
        cameraOffset.dx,
        cameraOffset.dy,
        size.width,
        size.height,
      ).inflate(ScenePainter._cullPadding),
      selectedIds: controller.selectedNodeIds,
      selectionRect: selectionRect,
      selectionStyle: _SelectionStyle(
        color: selectionColor,
        haloWidth: clampNonNegativeFinite(selectionStrokeWidth),
      ),
    );
  }

  _ResolvedNodePaintData resolveNodePaintData(NodeSnapshot node) {
    return _ResolvedNodePaintData(
      node: node,
      previewDelta: _nodePreviewOffset(node.id),
      geometry: geometryCache.get(node),
    );
  }

  bool canPaintNodeInFrame(_ResolvedNodePaintData node, Rect viewRect) {
    final worldBounds = node.worldBounds;
    return _isFiniteRect(worldBounds) && viewRect.overlaps(worldBounds);
  }

  Offset _nodePreviewOffset(NodeId nodeId) {
    return sanitizeFiniteOffset(
      nodePreviewOffsetResolver?.call(nodeId) ?? Offset.zero,
    );
  }
}

class _PaintFrame {
  _PaintFrame({
    required this.cameraOffset,
    required this.viewRect,
    required this.selectedIds,
    required this.selectionRect,
    required this.selectionStyle,
  });

  final Offset cameraOffset;
  final Rect viewRect;
  final Set<NodeId> selectedIds;
  final Rect? selectionRect;
  final _SelectionStyle selectionStyle;
  final List<_ResolvedNodePaintData> selectedNodes = <_ResolvedNodePaintData>[];

  bool get hasNodeSelection =>
      selectedNodes.isNotEmpty && selectionStyle.haloWidth > 0;

  bool isSelected(NodeId nodeId) => selectedIds.contains(nodeId);
}

class _SelectionStyle {
  const _SelectionStyle({required this.color, required this.haloWidth});

  final Color color;
  final double haloWidth;
}

class _ResolvedNodePaintData {
  const _ResolvedNodePaintData({
    required this.node,
    required this.previewDelta,
    required this.geometry,
  });

  final NodeSnapshot node;
  final Offset previewDelta;
  final GeometryEntry geometry;

  Rect get worldBounds {
    if (previewDelta == Offset.zero) {
      return geometry.worldBounds;
    }
    return geometry.worldBounds.shift(previewDelta);
  }
}
