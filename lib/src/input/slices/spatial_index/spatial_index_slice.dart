import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/nodes.dart';
import '../../../core/scene.dart';
import '../../../core/scene_spatial_index.dart';
import '../../../controller/change_set.dart';

class V2SpatialIndexSlice {
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
    final prepared = writePrepareCommit(
      scene: scene,
      nodeLocator: nodeLocator,
      changeSet: changeSet,
      controllerEpoch: controllerEpoch,
    );
    writeApplyPreparedCommit(prepared);
  }

  Object writePrepareCommit({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
    required ChangeSet changeSet,
    required int controllerEpoch,
  }) {
    if (_index == null) {
      return _PreparedSpatialIndexCommit.setEpochOnly(
        controllerEpoch: controllerEpoch,
      );
    }

    final epochChanged = _indexEpoch != controllerEpoch;
    if (changeSet.documentReplaced || epochChanged) {
      return const _PreparedSpatialIndexCommit.invalidate();
    }

    final hasSpatialChange =
        changeSet.structuralChanged ||
        changeSet.boundsChanged ||
        changeSet.addedNodeIds.isNotEmpty ||
        changeSet.removedNodeIds.isNotEmpty ||
        changeSet.hitGeometryChangedIds.isNotEmpty;
    if (!hasSpatialChange) {
      return const _PreparedSpatialIndexCommit.noop();
    }

    final hasIncrementalDelta =
        changeSet.addedNodeIds.isNotEmpty ||
        changeSet.removedNodeIds.isNotEmpty ||
        changeSet.hitGeometryChangedIds.isNotEmpty;
    if (!hasIncrementalDelta) {
      return const _PreparedSpatialIndexCommit.invalidate();
    }

    try {
      debugBeforeIncrementalPrepareHook?.call();
      final candidate = _index!.cloneForIncrementalUpdate(
        scene: scene,
        nodeLocator: nodeLocator,
      );
      final applied = candidate.applyIncremental(
        scene: scene,
        nodeLocator: nodeLocator,
        addedNodeIds: changeSet.addedNodeIds,
        removedNodeIds: changeSet.removedNodeIds,
        hitGeometryChangedIds: changeSet.hitGeometryChangedIds,
      );
      if (applied) {
        return _PreparedSpatialIndexCommit.swapIncremental(
          candidate: candidate,
          controllerEpoch: controllerEpoch,
        );
      }
    } catch (_) {
      // Fall through to full rebuild.
    }

    return _prepareFallbackRebuild(
      scene: scene,
      nodeLocator: nodeLocator,
      controllerEpoch: controllerEpoch,
    );
  }

  void writeApplyPreparedCommit(Object preparedCommit) {
    final prepared = preparedCommit as _PreparedSpatialIndexCommit;
    switch (prepared.mode) {
      case _PreparedSpatialIndexCommitMode.noop:
        return;
      case _PreparedSpatialIndexCommitMode.setEpochOnly:
        _indexEpoch = prepared.controllerEpoch!;
        return;
      case _PreparedSpatialIndexCommitMode.invalidate:
        _invalidate();
        return;
      case _PreparedSpatialIndexCommitMode.swapIncremental:
        _index = prepared.candidate;
        _indexEpoch = prepared.controllerEpoch!;
        _debugIncrementalApplyCount = _debugIncrementalApplyCount + 1;
        return;
      case _PreparedSpatialIndexCommitMode.replaceRebuilt:
        _index = prepared.candidate;
        _indexEpoch = prepared.controllerEpoch!;
        _debugBuildCount = _debugBuildCount + 1;
        return;
    }
  }

  _PreparedSpatialIndexCommit _prepareFallbackRebuild({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
    required int controllerEpoch,
  }) {
    debugBeforeFallbackRebuildHook?.call();
    final rebuilt = SceneSpatialIndex.build(scene, nodeLocator: nodeLocator);
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
