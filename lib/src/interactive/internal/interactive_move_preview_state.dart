import 'dart:ui';

import '../../contract/ids.dart';

final class InteractiveMovePreviewState {
  bool _active = false;
  Offset _delta = Offset.zero;
  Set<NodeId> _nodeIds = <NodeId>{};

  bool get isActive => _active;
  bool get hasTranslation =>
      _active && _nodeIds.isNotEmpty && _delta != Offset.zero;
  Offset get delta => _delta;

  Offset deltaForNode(NodeId nodeId) {
    if (!_active || !_nodeIds.contains(nodeId)) {
      return Offset.zero;
    }
    return _delta;
  }

  bool start(Set<NodeId> nodeIds) {
    _active = true;
    _delta = Offset.zero;
    _nodeIds = Set<NodeId>.from(nodeIds);
    return true;
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
