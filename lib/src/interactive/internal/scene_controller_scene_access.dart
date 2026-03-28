import 'dart:ui';

import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_write_txn.dart';
import '../../contract/snapshot.dart';
import 'scene_controller_scene_mutations.dart';

abstract interface class SceneControllerSceneAccess {
  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  });

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

final class SceneControllerSceneAccessAdapter
    implements SceneControllerSceneAccess {
  const SceneControllerSceneAccessAdapter({
    required this.ensurePublicSideEffectAllowedCallback,
    required this.mutations,
  });

  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowedCallback;
  final SceneControllerSceneMutations mutations;

  @override
  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {
    ensurePublicSideEffectAllowedCallback(
      operation,
      allowAfterDispose: allowAfterDispose,
    );
  }

  @override
  T write<T>(T Function(SceneWriteTxn writer) fn) {
    return mutations.write(fn);
  }

  @override
  void setBackgroundColor(Color value) {
    mutations.setBackgroundColor(value);
  }

  @override
  void setGridEnabled(bool value) {
    mutations.setGridEnabled(value);
  }

  @override
  void setGridCellSize(double value) {
    mutations.setGridCellSize(value);
  }

  @override
  void setCameraOffset(Offset value) {
    mutations.setCameraOffset(value);
  }

  @override
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    return mutations.addNode(node, layerId: layerId, insertIndex: insertIndex);
  }

  @override
  bool ensureLayer(LayerId layerId, {int? index}) {
    return mutations.ensureLayer(layerId, index: index);
  }

  @override
  bool patchNode(NodePatch patch) {
    return mutations.patchNode(patch);
  }

  @override
  bool removeNode(NodeId id, {int? timestampMs}) {
    return mutations.removeNode(id, timestampMs: timestampMs);
  }

  @override
  void clearScene({int? timestampMs}) {
    mutations.clearScene(timestampMs: timestampMs);
  }

  @override
  void replaceScene(SceneSnapshot snapshot) {
    mutations.replaceScene(snapshot);
  }

  @override
  void notifySceneChanged() {
    mutations.notifySceneChanged();
  }
}
