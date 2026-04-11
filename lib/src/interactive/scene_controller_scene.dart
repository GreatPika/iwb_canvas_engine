import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import 'internal/scene_controller_scene_mutations.dart';

abstract interface class SceneControllerScene {
  T write<T>(T Function(SceneWriteTxn writer) fn);
  void setBackgroundColor(Color value);
  void setGridEnabled(bool value);
  void setGridCellSize(double value);
  void setCameraOffset(Offset value);
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex});
  bool ensureLayer(LayerId layerId, {int? index});
  bool patchNode(NodePatch patch);
  bool removeNode(NodeId id, {int? timestampMs});
  void clearScene({int? timestampMs});
  void replaceScene(SceneSnapshot snapshot);
  void notifySceneChanged();
}

class SceneControllerSceneOwner implements SceneControllerScene {
  const SceneControllerSceneOwner({
    required this.ensurePublicSideEffectAllowed,
    required SceneControllerSceneMutations mutations,
  }) : _mutations = mutations;

  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed;
  final SceneControllerSceneMutations _mutations;

  @override
  T write<T>(T Function(SceneWriteTxn writer) fn) {
    ensurePublicSideEffectAllowed('write');
    return _mutations.write(fn);
  }

  @override
  void setBackgroundColor(Color value) {
    ensurePublicSideEffectAllowed('setBackgroundColor');
    _mutations.setBackgroundColor(value);
  }

  @override
  void setGridEnabled(bool value) {
    ensurePublicSideEffectAllowed('setGridEnabled');
    _mutations.setGridEnabled(value);
  }

  @override
  void setGridCellSize(double value) {
    ensurePublicSideEffectAllowed('setGridCellSize');
    _mutations.setGridCellSize(value);
  }

  @override
  void setCameraOffset(Offset value) {
    ensurePublicSideEffectAllowed('setCameraOffset');
    _mutations.setCameraOffset(value);
  }

  @override
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    ensurePublicSideEffectAllowed('addNode');
    return _mutations.addNode(node, layerId: layerId, insertIndex: insertIndex);
  }

  @override
  bool ensureLayer(LayerId layerId, {int? index}) {
    ensurePublicSideEffectAllowed('ensureLayer');
    return _mutations.ensureLayer(layerId, index: index);
  }

  @override
  bool patchNode(NodePatch patch) {
    ensurePublicSideEffectAllowed('patchNode');
    return _mutations.patchNode(patch);
  }

  @override
  bool removeNode(NodeId id, {int? timestampMs}) {
    ensurePublicSideEffectAllowed('removeNode');
    return _mutations.removeNode(id, timestampMs: timestampMs);
  }

  @override
  void clearScene({int? timestampMs}) {
    ensurePublicSideEffectAllowed('clearScene');
    _mutations.clearScene(timestampMs: timestampMs);
  }

  @override
  void replaceScene(SceneSnapshot snapshot) {
    ensurePublicSideEffectAllowed('replaceScene');
    _mutations.replaceScene(snapshot);
  }

  @override
  void notifySceneChanged() {
    ensurePublicSideEffectAllowed('notifySceneChanged');
    _mutations.notifySceneChanged();
  }
}
