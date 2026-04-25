import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/ids.dart' show LayerId;
import '../../core/nodes.dart';
import '../../core/scene.dart';
import '../../core/scene_spatial_index.dart';
import '../../core/scene_node_locator.dart';
import '../change_set.dart';

class SpatialIndexCache {
  SceneSpatialIndex? _index;
  int _indexEpoch = -1;
  int _debugBuildCount = 0;
  int _debugIncrementalApplyCount = 0;

  @visibleForTesting
  void Function()? debugBeforeIncrementalPrepareHook;
  @visibleForTesting
  void Function()? debugBeforeFallbackRebuildHook;

  int get debugBuildCount => _debugBuildCount;
  int get debugIncrementalApplyCount => _debugIncrementalApplyCount;

  List<SceneHitTestSpatialCandidate> writeQueryHitTestCandidates({
    required Scene scene,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required Map<LayerId, int> layerIndexById,
    required Rect worldBounds,
    required int controllerEpoch,
    required int structuralRevision,
  }) {
    final needsBuild = _index == null || _indexEpoch != controllerEpoch;
    if (needsBuild) {
      _index = SceneSpatialIndex.build(
        scene,
        nodeLocator: nodeLocator,
        layerIndexById: layerIndexById,
        structuralRevision: structuralRevision,
      );
      _indexEpoch = controllerEpoch;
      _debugBuildCount = _debugBuildCount + 1;
    }
    final index = _index;
    if (index == null) {
      return const <SceneHitTestSpatialCandidate>[];
    }
    return index.queryHitTestCandidates(worldBounds);
  }

  List<ScenePaintSpatialCandidate> writeQueryPaintCandidates({
    required Scene scene,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required Map<LayerId, int> layerIndexById,
    required Rect worldBounds,
    required int controllerEpoch,
    required int structuralRevision,
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) {
    final needsBuild = _index == null || _indexEpoch != controllerEpoch;
    if (needsBuild) {
      _index = SceneSpatialIndex.build(
        scene,
        nodeLocator: nodeLocator,
        layerIndexById: layerIndexById,
        structuralRevision: structuralRevision,
      );
      _indexEpoch = controllerEpoch;
      _debugBuildCount = _debugBuildCount + 1;
    }
    final index = _index;
    if (index == null) {
      return const <ScenePaintSpatialCandidate>[];
    }
    return index.queryPaintCandidates(worldBounds, scope: scope);
  }

  void writeHandleCommit({
    required Scene scene,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required Map<LayerId, int> layerIndexById,
    required ChangeSet changeSet,
    required int controllerEpoch,
    required int structuralRevision,
  }) {
    final prepared = writePrepareCommit(
      scene: scene,
      nodeLocator: nodeLocator,
      layerIndexById: layerIndexById,
      changeSet: changeSet,
      controllerEpoch: controllerEpoch,
      structuralRevision: structuralRevision,
    );
    writeApplyPreparedCommit(prepared);
  }

  Object writePrepareCommit({
    required Scene scene,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required Map<LayerId, int> layerIndexById,
    required ChangeSet changeSet,
    required int controllerEpoch,
    required int structuralRevision,
  }) {
    final coldStart = _prepareColdStartEpoch(_index, controllerEpoch);
    if (coldStart != null) {
      return coldStart;
    }

    if (_requiresInvalidation(
      changeSet: changeSet,
      currentEpoch: _indexEpoch,
      nextEpoch: controllerEpoch,
    )) {
      return const _PreparedSpatialIndexCommit.invalidate();
    }

    if (!_hasSpatialChange(changeSet)) {
      return const _PreparedSpatialIndexCommit.noop();
    }

    if (!_hasIncrementalDelta(changeSet)) {
      return const _PreparedSpatialIndexCommit.invalidate();
    }

    final incremental = _prepareIncrementalCommit(
      _IncrementalPrepareArgs(
        index: _index,
        beforePrepareHook: debugBeforeIncrementalPrepareHook,
        scene: scene,
        nodeLocator: nodeLocator,
        layerIndexById: layerIndexById,
        changeSet: changeSet,
        controllerEpoch: controllerEpoch,
        structuralRevision: structuralRevision,
      ),
    );
    if (incremental != null) {
      return incremental;
    }

    return _prepareFallbackRebuild(
      scene: scene,
      nodeLocator: nodeLocator,
      layerIndexById: layerIndexById,
      controllerEpoch: controllerEpoch,
      structuralRevision: structuralRevision,
    );
  }

  void writeApplyPreparedCommit(Object preparedCommit) {
    final prepared = preparedCommit as _PreparedSpatialIndexCommit;
    switch (prepared.mode) {
      case _PreparedSpatialIndexCommitMode.noop:
        return;
      case _PreparedSpatialIndexCommitMode.setEpochOnly:
        // ignore: avoid-non-null-assertion, setEpochOnly always stores epoch
        _indexEpoch = prepared.controllerEpoch!;
        return;
      case _PreparedSpatialIndexCommitMode.invalidate:
        _invalidate();
        return;
      case _PreparedSpatialIndexCommitMode.swapIncremental:
        _index = prepared.candidate;
        // ignore: avoid-non-null-assertion, swapIncremental always stores epoch
        _indexEpoch = prepared.controllerEpoch!;
        _debugIncrementalApplyCount = _debugIncrementalApplyCount + 1;
        return;
      case _PreparedSpatialIndexCommitMode.replaceRebuilt:
        _index = prepared.candidate;
        // ignore: avoid-non-null-assertion, replaceRebuilt always stores epoch
        _indexEpoch = prepared.controllerEpoch!;
        _debugBuildCount = _debugBuildCount + 1;
        return;
    }
  }

  _PreparedSpatialIndexCommit _prepareFallbackRebuild({
    required Scene scene,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required Map<LayerId, int> layerIndexById,
    required int controllerEpoch,
    required int structuralRevision,
  }) {
    debugBeforeFallbackRebuildHook?.call();
    final rebuilt = SceneSpatialIndex.build(
      scene,
      nodeLocator: nodeLocator,
      layerIndexById: layerIndexById,
      structuralRevision: structuralRevision,
    );
    return _PreparedSpatialIndexCommit.replaceRebuilt(
      candidate: rebuilt,
      controllerEpoch: controllerEpoch,
    );
  }

  void _invalidate() {
    _index = null;
    _indexEpoch = -1;
  }
}

_PreparedSpatialIndexCommit? _prepareColdStartEpoch(
  SceneSpatialIndex? index,
  int controllerEpoch,
) {
  if (index != null) {
    return null;
  }
  return _PreparedSpatialIndexCommit.setEpochOnly(
    controllerEpoch: controllerEpoch,
  );
}

bool _requiresInvalidation({
  required ChangeSet changeSet,
  required int currentEpoch,
  required int nextEpoch,
}) {
  return changeSet.documentReplaced || currentEpoch != nextEpoch;
}

bool _hasSpatialChange(ChangeSet changeSet) {
  return changeSet.structuralChanged ||
      changeSet.boundsChanged ||
      changeSet.addedNodeIds.isNotEmpty ||
      changeSet.removedNodeIds.isNotEmpty ||
      changeSet.spatialGeometryChangedIds.isNotEmpty;
}

bool _hasIncrementalDelta(ChangeSet changeSet) {
  return changeSet.addedNodeIds.isNotEmpty ||
      changeSet.removedNodeIds.isNotEmpty ||
      changeSet.spatialGeometryChangedIds.isNotEmpty;
}

_PreparedSpatialIndexCommit? _prepareIncrementalCommit(
  _IncrementalPrepareArgs args,
) {
  try {
    args.beforePrepareHook?.call();
    // ignore: avoid-non-null-assertion, guarded by cold-start path
    final candidate = args.index!.cloneForIncrementalUpdate(
      scene: args.scene,
      nodeLocator: args.nodeLocator,
      layerIndexById: args.layerIndexById,
      structuralRevision: args.structuralRevision,
    );
    final applied = candidate.applyIncremental(
      scene: args.scene,
      nodeLocator: args.nodeLocator,
      layerIndexById: args.layerIndexById,
      structuralRevision: args.structuralRevision,
      changeSet: SceneSpatialIndexChangeSet(
        addedNodeIds: args.changeSet.addedNodeIds,
        removedNodeIds: args.changeSet.removedNodeIds,
        spatialGeometryChangedIds: args.changeSet.spatialGeometryChangedIds,
      ),
    );
    if (!applied) {
      return null;
    }
    return _PreparedSpatialIndexCommit.swapIncremental(
      candidate: candidate,
      controllerEpoch: args.controllerEpoch,
    );
  } catch (_) {
    return null;
  }
}

class _IncrementalPrepareArgs {
  const _IncrementalPrepareArgs({
    required this.index,
    required this.beforePrepareHook,
    required this.scene,
    required this.nodeLocator,
    required this.layerIndexById,
    required this.changeSet,
    required this.controllerEpoch,
    required this.structuralRevision,
  });

  final SceneSpatialIndex? index;
  final void Function()? beforePrepareHook;
  final Scene scene;
  final Map<NodeId, NodeLocatorEntry> nodeLocator;
  final Map<LayerId, int> layerIndexById;
  final ChangeSet changeSet;
  final int controllerEpoch;
  final int structuralRevision;
}

class _PreparedSpatialIndexCommit {
  const _PreparedSpatialIndexCommit._({
    required this.mode,
    required this.controllerEpoch,
    required this.candidate,
  });

  const _PreparedSpatialIndexCommit.noop()
    : this._(
        mode: _PreparedSpatialIndexCommitMode.noop,
        controllerEpoch: null,
        candidate: null,
      );

  const _PreparedSpatialIndexCommit.setEpochOnly({required int controllerEpoch})
    : this._(
        mode: _PreparedSpatialIndexCommitMode.setEpochOnly,
        controllerEpoch: controllerEpoch,
        candidate: null,
      );

  const _PreparedSpatialIndexCommit.invalidate()
    : this._(
        mode: _PreparedSpatialIndexCommitMode.invalidate,
        controllerEpoch: null,
        candidate: null,
      );

  const _PreparedSpatialIndexCommit.swapIncremental({
    required SceneSpatialIndex candidate,
    required int controllerEpoch,
  }) : this._(
         mode: _PreparedSpatialIndexCommitMode.swapIncremental,
         controllerEpoch: controllerEpoch,
         candidate: candidate,
       );

  const _PreparedSpatialIndexCommit.replaceRebuilt({
    required SceneSpatialIndex candidate,
    required int controllerEpoch,
  }) : this._(
         mode: _PreparedSpatialIndexCommitMode.replaceRebuilt,
         controllerEpoch: controllerEpoch,
         candidate: candidate,
       );

  final _PreparedSpatialIndexCommitMode mode;
  final int? controllerEpoch;
  final SceneSpatialIndex? candidate;
}

enum _PreparedSpatialIndexCommitMode {
  noop,
  setEpochOnly,
  invalidate,
  swapIncremental,
  replaceRebuilt,
}
