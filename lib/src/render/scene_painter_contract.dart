import 'dart:ui';

import '../contract/scene_view_render_state.dart';
import '../contract/snapshot.dart';
import '../core/text_layout.dart';
import 'render_geometry_cache.dart';

class ScenePainterSelectionStyle {
  const ScenePainterSelectionStyle({
    required this.color,
    required this.haloWidth,
  });

  final Color color;
  final double haloWidth;
}

class ScenePainterPaintFrame {
  ScenePainterPaintFrame({
    required this.cameraOffset,
    required this.viewRect,
    required this.paintCandidates,
    required this.selectedIds,
    required this.selectionStyle,
  });

  final Offset cameraOffset;
  final Rect viewRect;
  final List<ScenePaintCandidate> paintCandidates;
  final Set<NodeId> selectedIds;
  final ScenePainterSelectionStyle selectionStyle;
  final List<ScenePainterResolvedNodePaintData> selectedNodes =
      <ScenePainterResolvedNodePaintData>[];

  bool get hasNodeSelection =>
      selectedNodes.isNotEmpty && selectionStyle.haloWidth > 0;

  bool isSelected(NodeId nodeId) => selectedIds.contains(nodeId);

  Rect visibilityRectForNode(NodeId nodeId) {
    final deflateBy = _frameVisibilityOutset - _nodeVisibilityOutset(nodeId);
    if (deflateBy <= 0) {
      return viewRect;
    }
    return viewRect.deflate(deflateBy);
  }

  double get _frameVisibilityOutset =>
      _visibilityOutset(hasSelectionHalo: selectedIds.isNotEmpty);

  double _nodeVisibilityOutset(NodeId nodeId) =>
      _visibilityOutset(hasSelectionHalo: isSelected(nodeId));

  double _visibilityOutset({required bool hasSelectionHalo}) {
    final haloOutset = hasSelectionHalo ? selectionStyle.haloWidth : 0.0;
    return haloOutset > 1.0 ? haloOutset : 1.0;
  }
}

class ScenePainterResolvedNodePaintData {
  const ScenePainterResolvedNodePaintData({
    required this.node,
    required this.previewDelta,
    required this.geometry,
    this.textLayout,
  });

  final NodeSnapshot node;
  final Offset previewDelta;
  final GeometryEntry geometry;
  final ResolvedTextLayout? textLayout;

  Rect get worldBounds {
    if (previewDelta == Offset.zero) {
      return geometry.worldBounds;
    }
    return geometry.worldBounds.shift(previewDelta);
  }
}
