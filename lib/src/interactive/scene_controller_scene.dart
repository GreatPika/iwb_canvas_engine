import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import 'internal/scene_controller_interaction_runtime.dart';
import 'internal/scene_controller_mutation_boundary.dart';

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
    required SceneControllerInteractionRuntime runtime,
    required SceneControllerMutationBoundary mutationBoundary,
  }) : _runtime = runtime,
       _mutationBoundary = mutationBoundary;

  final SceneControllerInteractionRuntime _runtime;
  final SceneControllerMutationBoundary _mutationBoundary;

  @override
  T write<T>(T Function(SceneWriteTxn writer) fn) {
    _runtime.ensurePublicSideEffectAllowed('write');
    _ensureExternalMutationAllowed('write');
    return _mutationBoundary.write(fn);
  }

  @override
  void setBackgroundColor(Color value) {
    _runtime.ensurePublicSideEffectAllowed('setBackgroundColor');
    _ensureExternalMutationAllowed('setBackgroundColor');
    _mutationBoundary.setBackgroundColor(value);
  }

  @override
  void setGridEnabled(bool value) {
    _runtime.ensurePublicSideEffectAllowed('setGridEnabled');
    _ensureExternalMutationAllowed('setGridEnabled');
    _mutationBoundary.setGridEnabled(value);
  }

  @override
  void setGridCellSize(double value) {
    _runtime.ensurePublicSideEffectAllowed('setGridCellSize');
    _ensureExternalMutationAllowed('setGridCellSize');
    _mutationBoundary.setGridCellSize(value);
  }

  @override
  void setCameraOffset(Offset value) {
    _runtime.ensurePublicSideEffectAllowed('setCameraOffset');
    _mutationBoundary.validateCameraOffset(value);
    if (!_mutationBoundary.shouldApplyCameraOffset(value)) {
      return;
    }
    _interruptForExternalMutation();
    _mutationBoundary.setCameraOffset(value);
  }

  @override
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    _runtime.ensurePublicSideEffectAllowed('addNode');
    _ensureExternalMutationAllowed('addNode');
    return _mutationBoundary.addNode(
      node,
      layerId: layerId,
      insertIndex: insertIndex,
    );
  }

  @override
  bool ensureLayer(LayerId layerId, {int? index}) {
    _runtime.ensurePublicSideEffectAllowed('ensureLayer');
    _ensureExternalMutationAllowed('ensureLayer');
    return _mutationBoundary.ensureLayer(layerId, index: index);
  }

  @override
  bool patchNode(NodePatch patch) {
    _runtime.ensurePublicSideEffectAllowed('patchNode');
    _ensureExternalMutationAllowed('patchNode');
    return _mutationBoundary.patchNode(patch);
  }

  @override
  bool removeNode(NodeId id, {int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('removeNode');
    _ensureExternalMutationAllowed('removeNode');
    return _mutationBoundary.removeNode(id, timestampMs: timestampMs);
  }

  @override
  void clearScene({int? timestampMs}) {
    _runtime.ensurePublicSideEffectAllowed('clearScene');
    _ensureExternalMutationAllowed('clearScene');
    _mutationBoundary.clearScene(timestampMs: timestampMs);
  }

  @override
  void replaceScene(SceneSnapshot snapshot) {
    _runtime.ensurePublicSideEffectAllowed('replaceScene');
    _mutationBoundary.replaceScene(
      snapshot,
      interruptBeforeApply: _interruptForExternalMutation,
    );
  }

  @override
  void notifySceneChanged() {
    _runtime.ensurePublicSideEffectAllowed('notifySceneChanged');
    _mutationBoundary.notifySceneChanged();
  }

  void _ensureExternalMutationAllowed(String operation) {
    _runtime.ensureExternalMutationAllowed(operation);
  }

  void _interruptForExternalMutation() {
    _runtime.interruptForExternalMutation();
  }
}
