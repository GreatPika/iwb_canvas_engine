import 'dart:ui';

import '../../../core/scene.dart';
import '../../../core/scene_spatial_index.dart';
import '../../../controller/change_set.dart';

class V2SpatialIndexSlice {
  SceneSpatialIndex? _index;
  int _indexEpoch = -1;
  int _indexBoundsRevision = -1;
  int _debugBuildCount = 0;

  int get debugBuildCount => _debugBuildCount;

  List<SceneSpatialCandidate> writeQueryCandidates({
    required Scene scene,
    required Rect worldBounds,
    required int controllerEpoch,
    required int boundsRevision,
  }) {
    final needsBuild =
        _index == null ||
        _indexEpoch != controllerEpoch ||
        _indexBoundsRevision != boundsRevision;
    if (needsBuild) {
      _index = SceneSpatialIndex.build(scene);
      _indexEpoch = controllerEpoch;
      _indexBoundsRevision = boundsRevision;
      _debugBuildCount = _debugBuildCount + 1;
    }
    return _index!.query(worldBounds);
  }

  void writeHandleCommit({
    required ChangeSet changeSet,
    required int controllerEpoch,
    required int boundsRevision,
  }) {
    final needsInvalidation =
        changeSet.documentReplaced ||
        changeSet.structuralChanged ||
        changeSet.boundsChanged ||
        _indexEpoch != controllerEpoch ||
        _indexBoundsRevision != boundsRevision;
    if (!needsInvalidation) {
      return;
    }

    _index = null;
    _indexEpoch = -1;
    _indexBoundsRevision = -1;
  }
}
