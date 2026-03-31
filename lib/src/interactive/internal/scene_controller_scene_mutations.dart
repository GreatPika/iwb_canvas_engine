import 'dart:ui';

import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_write_txn.dart';
import '../../contract/snapshot.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerSceneMutations {
  const SceneControllerSceneMutations({
    required this.mutations,
    required this.ensureExternalMutationAllowed,
    required this.resetActiveGestureBeforeExternalMutation,
  });

  final SceneControllerMutationBoundary mutations;
  final void Function(String operation) ensureExternalMutationAllowed;
  final VoidCallback resetActiveGestureBeforeExternalMutation;

  T write<T>(T Function(SceneWriteTxn writer) fn) {
    ensureExternalMutationAllowed('write');
    return mutations.write(fn);
  }

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    ensureExternalMutationAllowed('addNode');
    return mutations.addNode(node, layerId: layerId, insertIndex: insertIndex);
  }

  bool ensureLayer(LayerId layerId, {int? index}) {
    ensureExternalMutationAllowed('ensureLayer');
    return mutations.ensureLayer(layerId, index: index);
  }

  bool patchNode(NodePatch patch) {
    ensureExternalMutationAllowed('patchNode');
    return mutations.patchNode(patch);
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    ensureExternalMutationAllowed('removeNode');
    return mutations.removeNode(id, timestampMs: timestampMs);
  }

  void setBackgroundColor(Color value) {
    ensureExternalMutationAllowed('setBackgroundColor');
    mutations.setBackgroundColor(value);
  }

  void setGridEnabled(bool value) {
    ensureExternalMutationAllowed('setGridEnabled');
    mutations.setGridEnabled(value);
  }

  void setGridCellSize(double value) {
    ensureExternalMutationAllowed('setGridCellSize');
    mutations.setGridCellSize(value);
  }

  void setCameraOffset(Offset value) {
    mutations.validateCameraOffset(value);
    if (!mutations.shouldApplyCameraOffset(value)) {
      return;
    }
    resetActiveGestureBeforeExternalMutation();
    mutations.setCameraOffset(value);
  }

  void clearScene({int? timestampMs}) {
    ensureExternalMutationAllowed('clearScene');
    mutations.clearScene(timestampMs: timestampMs);
  }

  void replaceScene(SceneSnapshot snapshot) {
    final replacement = mutations.prepareSceneReplacement(snapshot);
    resetActiveGestureBeforeExternalMutation();
    mutations.replaceScene(replacement);
  }

  void notifySceneChanged() {
    mutations.notifySceneChanged();
  }
}
