import 'dart:ui';

import '../../../core/nodes.dart';
import '../../../core/scene.dart';
import '../../../core/scene_spatial_index.dart';
import '../../../controller/change_set.dart';

class V2SpatialIndexSlice {
  SceneSpatialIndex? _index;
  int _indexEpoch = -1;
  int _debugBuildCount = 0;
  int _debugIncrementalApplyCount = 0;

  int get debugBuildCount => _debugBuildCount;
  int get debugIncrementalApplyCount => _debugIncrementalApplyCount;

  List<SceneSpatialCandidate> writeQueryCandidates({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
    required Rect worldBounds,
    required int controllerEpoch,
  }) {
    final needsBuild = _index == null || _indexEpoch != controllerEpoch;
    if (needsBuild) {
      _index = SceneSpatialIndex.build(scene, nodeLocator: nodeLocator);
      _indexEpoch = controllerEpoch;
      _debugBuildCount = _debugBuildCount + 1;
    }
    return _index!.query(worldBounds);
  }

  void writeHandleCommit({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
    required ChangeSet changeSet,
    required int controllerEpoch,
  }) {
    if (_index == null) {
      _indexEpoch = controllerEpoch;
      return;
    }

    final epochChanged = _indexEpoch != controllerEpoch;
    if (changeSet.documentReplaced || epochChanged) {
      _invalidate();
      return;
    }

    final hasSpatialChange =
        changeSet.structuralChanged ||
        changeSet.boundsChanged ||
        changeSet.addedNodeIds.isNotEmpty ||
        changeSet.removedNodeIds.isNotEmpty ||
        changeSet.hitGeometryChangedIds.isNotEmpty;
    if (!hasSpatialChange) {
      return;
    }

    final hasIncrementalDelta =
        changeSet.addedNodeIds.isNotEmpty ||
        changeSet.removedNodeIds.isNotEmpty ||
        changeSet.hitGeometryChangedIds.isNotEmpty;
    if (!hasIncrementalDelta) {
      _invalidate();
      return;
    }

    final applied = _index!.applyIncremental(
      scene: scene,
      nodeLocator: nodeLocator,
      addedNodeIds: changeSet.addedNodeIds,
      removedNodeIds: changeSet.removedNodeIds,
      hitGeometryChangedIds: changeSet.hitGeometryChangedIds,
    );
    if (!applied) {
      _invalidate();
      return;
    }

    _indexEpoch = controllerEpoch;
    _debugIncrementalApplyCount = _debugIncrementalApplyCount + 1;
  }

  void _invalidate() {
    _index = null;
    _indexEpoch = -1;
  }
}
