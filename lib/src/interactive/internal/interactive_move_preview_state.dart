import 'dart:ui';

import '../../contract/ids.dart';
import '../../contract/scene_view_render_state.dart';

final class InteractiveMovePreviewState {
  bool _active = false;
  Offset _delta = Offset.zero;
  Set<NodeId> _nodeIds = <NodeId>{};

  bool get hasTranslation =>
      _active && _nodeIds.isNotEmpty && _delta != Offset.zero;
  bool get hasSceneEffect => hasTranslation;
  Offset get delta => _delta;

  Offset deltaForNode(NodeId nodeId) {
    if (!_active || !_nodeIds.contains(nodeId)) {
      return Offset.zero;
    }
    return _delta;
  }

  SceneViewFramePreview captureFramePreview() {
    if (!_active || _nodeIds.isEmpty) {
      return const SceneViewFramePreview.empty();
    }
    return SceneViewFramePreview.captureNodeOffsets(
      nodeIds: _nodeIds,
      deltaForNode: deltaForNode,
    );
  }

  void start(Set<NodeId> nodeIds) {
    _active = true;
    _delta = Offset.zero;
    _nodeIds = Set<NodeId>.from(nodeIds);
  }

  bool advance(Offset scenePoint, Offset lastScenePoint) {
    final deltaStep = scenePoint - lastScenePoint;
    if (deltaStep == Offset.zero) {
      return false;
    }
    _delta = _delta + deltaStep;
    return true;
  }

  void clear() {
    _active = false;
    _delta = Offset.zero;
    _nodeIds = <NodeId>{};
  }
}
