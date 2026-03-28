import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import 'internal/scene_controller_scene_mutations.dart';

class SceneControllerScene {
  const SceneControllerScene({
    required this.ensurePublicSideEffectAllowed,
    required SceneControllerSceneMutations mutations,
  }) : _mutations = mutations;

  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed;
  final SceneControllerSceneMutations _mutations;

  T write<T>(T Function(SceneWriteTxn writer) fn) {
    ensurePublicSideEffectAllowed('write');
    return _mutations.write(fn);
  }

  void setBackgroundColor(Color value) {
    ensurePublicSideEffectAllowed('setBackgroundColor');
    _mutations.setBackgroundColor(value);
  }

  void setGridEnabled(bool value) {
    ensurePublicSideEffectAllowed('setGridEnabled');
    _mutations.setGridEnabled(value);
  }

  void setGridCellSize(double value) {
    ensurePublicSideEffectAllowed('setGridCellSize');
    _mutations.setGridCellSize(value);
  }

  void setCameraOffset(Offset value) {
    ensurePublicSideEffectAllowed('setCameraOffset');
    _mutations.setCameraOffset(value);
  }

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    ensurePublicSideEffectAllowed('addNode');
    return _mutations.addNode(node, layerId: layerId, insertIndex: insertIndex);
  }

  bool ensureLayer(LayerId layerId, {int? index}) {
    ensurePublicSideEffectAllowed('ensureLayer');
    return _mutations.ensureLayer(layerId, index: index);
  }

  bool patchNode(NodePatch patch) {
    ensurePublicSideEffectAllowed('patchNode');
    return _mutations.patchNode(patch);
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    ensurePublicSideEffectAllowed('removeNode');
    return _mutations.removeNode(id, timestampMs: timestampMs);
  }

  void clearScene({int? timestampMs}) {
    ensurePublicSideEffectAllowed('clearScene');
    _mutations.clearScene(timestampMs: timestampMs);
  }

  void replaceScene(SceneSnapshot snapshot) {
    ensurePublicSideEffectAllowed('replaceScene');
    _mutations.replaceScene(snapshot);
  }

  void notifySceneChanged() {
    ensurePublicSideEffectAllowed('notifySceneChanged');
    _mutations.notifySceneChanged();
  }
}
