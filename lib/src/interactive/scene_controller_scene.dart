import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import 'internal/scene_controller_scene_access.dart';

class SceneControllerScene {
  SceneControllerScene(this._access);

  final SceneControllerSceneAccess _access;

  T write<T>(T Function(SceneWriteTxn writer) fn) {
    _access.ensurePublicSideEffectAllowed('write');
    return _access.write(fn);
  }

  void setBackgroundColor(Color value) {
    _access.ensurePublicSideEffectAllowed('setBackgroundColor');
    _access.setBackgroundColor(value);
  }

  void setGridEnabled(bool value) {
    _access.ensurePublicSideEffectAllowed('setGridEnabled');
    _access.setGridEnabled(value);
  }

  void setGridCellSize(double value) {
    _access.ensurePublicSideEffectAllowed('setGridCellSize');
    _access.setGridCellSize(value);
  }

  void setCameraOffset(Offset value) {
    _access.ensurePublicSideEffectAllowed('setCameraOffset');
    _access.setCameraOffset(value);
  }

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    _access.ensurePublicSideEffectAllowed('addNode');
    return _access.addNode(node, layerId: layerId, insertIndex: insertIndex);
  }

  bool ensureLayer(LayerId layerId, {int? index}) {
    _access.ensurePublicSideEffectAllowed('ensureLayer');
    return _access.ensureLayer(layerId, index: index);
  }

  bool patchNode(NodePatch patch) {
    _access.ensurePublicSideEffectAllowed('patchNode');
    return _access.patchNode(patch);
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    _access.ensurePublicSideEffectAllowed('removeNode');
    return _access.removeNode(id, timestampMs: timestampMs);
  }

  void clearScene({int? timestampMs}) {
    _access.ensurePublicSideEffectAllowed('clearScene');
    _access.clearScene(timestampMs: timestampMs);
  }

  void replaceScene(SceneSnapshot snapshot) {
    _access.ensurePublicSideEffectAllowed('replaceScene');
    _access.replaceScene(snapshot);
  }

  void notifySceneChanged() {
    _access.ensurePublicSideEffectAllowed('notifySceneChanged');
    _access.notifySceneChanged();
  }
}
