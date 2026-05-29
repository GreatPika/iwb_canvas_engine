import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import 'spatial_membership.dart';

final class OutlierIndex {
  final Map<CanvasElementId, FrameElementHandle> _handlesById = {};

  int get length => _handlesById.length;

  void clear() {
    _handlesById.clear();
  }

  bool contains(CanvasElementId id) => _handlesById.containsKey(id);

  void put(SpatialMembership membership) {
    if (!membership.isOutlier) {
      return;
    }
    _handlesById[membership.id] = membership.handle;
  }

  void remove(CanvasElementId id) {
    _handlesById.remove(id);
  }

  Iterable<FrameElementHandle> candidates() {
    return _handlesById.values;
  }
}
