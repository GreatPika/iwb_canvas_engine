import 'dart:ui';

import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_model_invariants.dart';
import '../../contract/scene_write_txn.dart';
import '../../contract/snapshot.dart';
import '../../contract/transform2d.dart';
import '../../core/action_events.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import '../interaction_eligibility_policy.dart'
    as interaction_eligibility_policy;
import 'interactive_move_callbacks.dart';

final class SceneControllerMutationBoundaryCallbacks {
  const SceneControllerMutationBoundaryCallbacks({
    required this.resolveTimestampMs,
    required this.emitAction,
    required this.resolveMoveCommitDelta,
    required this.requireFiniteOffset,
    required this.clearPointerNormalizationState,
    required this.schedulePublicNotify,
    required this.scheduleSceneRepaint,
    required this.scheduleOverlayRepaint,
  });

  final int Function(int? timestampMs) resolveTimestampMs;
  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;
  final Offset Function({
    required SceneSnapshot snapshot,
    required List<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  })
  resolveMoveCommitDelta;
  final void Function(Offset value, {required String name}) requireFiniteOffset;
  final VoidCallback clearPointerNormalizationState;
  final VoidCallback schedulePublicNotify;
  final VoidCallback scheduleSceneRepaint;
  final VoidCallback scheduleOverlayRepaint;
}

final class SceneControllerMutationBoundary {
  const SceneControllerMutationBoundary({
    required this.mutationAccess,
    required this.readSnapshot,
    required this.callbacks,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
  final SceneSnapshot Function() readSnapshot;
  final SceneControllerMutationBoundaryCallbacks callbacks;

  T write<T>(T Function(SceneWriteTxn writer) fn) {
    final result = mutationAccess.writeExact(fn);
    if (!result.didChangeRenderState) {
      return result.value;
    }
    // Opaque writes may affect scene, overlay, or both. Invalidate all
    // controller-facing channels because the public adapter cannot derive the
    // touched domain after the transaction closes.
    callbacks.schedulePublicNotify();
    callbacks.scheduleSceneRepaint();
    callbacks.scheduleOverlayRepaint();
    return result.value;
  }

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    final nodeId = mutationAccess.addNode(
      node,
      layerId: layerId,
      insertIndex: insertIndex,
    );
    _scheduleSceneCommit();
    return nodeId;
  }

  bool ensureLayer(LayerId layerId, {int? index}) {
    final changed = mutationAccess.ensureLayer(layerId, index: index);
    if (changed) {
      _scheduleSceneCommit();
    }
    return changed;
  }

  bool patchNode(NodePatch patch) {
    final changed = mutationAccess.patchNode(patch);
    if (changed) {
      _scheduleSceneCommit();
    }
    return changed;
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    final deleted = mutationAccess.removeNode(id);
    if (!deleted) {
      return false;
    }
    _scheduleSceneCommit();
    callbacks.emitAction(ActionType.delete, <NodeId>[
      id,
    ], callbacks.resolveTimestampMs(timestampMs));
    return true;
  }

  void setBackgroundColor(Color value) {
    if (!mutationAccess.setBackgroundColor(value)) {
      return;
    }
    _scheduleSceneCommit();
  }

  void setGridEnabled(bool value) {
    if (!mutationAccess.setGridEnabled(value)) {
      return;
    }
    _scheduleSceneCommit();
  }

  void setGridCellSize(double value) {
    validateSceneGridCellSize(
      value,
      name: 'cellSize',
      isEnabled: readSnapshot().background.grid.isEnabled,
    );
    if (!mutationAccess.setGridCellSize(value)) {
      return;
    }
    _scheduleSceneCommit();
  }

  void validateCameraOffset(Offset value) {
    validateSceneCameraOffset(value, name: 'value');
  }

  bool shouldApplyCameraOffset(Offset value) {
    return readSnapshot().camera.offset != value;
  }

  void setCameraOffset(Offset value) {
    if (!mutationAccess.setCameraOffset(value)) {
      return;
    }
    _scheduleSceneAndOverlayCommit();
  }

  void clearScene({int? timestampMs}) {
    final clearResult = mutationAccess.clearSceneExactResult();
    if (!clearResult.didStructuralClear) {
      return;
    }
    _scheduleSceneCommit();

    callbacks.emitAction(
      ActionType.clear,
      clearResult.removedNodeIds,
      callbacks.resolveTimestampMs(timestampMs),
    );
  }

  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback interruptBeforeApply,
  }) {
    mutationAccess.replaceScene(snapshot, beforeApply: interruptBeforeApply);
    callbacks.clearPointerNormalizationState();
    _scheduleSceneAndOverlayCommit();
  }

  void notifySceneChanged() {
    mutationAccess.requestRepaint();
    _scheduleSceneCommit();
  }

  void setSelection(Iterable<NodeId> nodeIds) {
    if (!mutationAccess.replaceSelection(nodeIds)) {
      return;
    }
    _scheduleSceneCommit();
  }

  void toggleSelection(NodeId nodeId) {
    if (!mutationAccess.toggleSelection(nodeId)) {
      return;
    }
    _scheduleSceneCommit();
  }

  void clearSelection() {
    if (!mutationAccess.clearSelection()) {
      return;
    }
    _scheduleSceneCommit();
  }

  void selectAll({bool onlySelectable = true}) {
    final result = mutationAccess.selectAll(onlySelectable: onlySelectable);
    if (!result.changed) {
      return;
    }
    _scheduleSceneCommit();
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    final nodes = interaction_eligibility_policy
        .selectedTransformableNodesInSnapshotOrder(
          snapshot: mutationAccess.snapshot,
          selected: mutationAccess.selectedNodeIds,
        );
    if (nodes.isEmpty) {
      return;
    }

    final center = mutationAccess.centerWorldForNodeSnapshots(nodes);
    final pivot = Transform2D.translation(center);
    final unpivot = Transform2D.translation(Offset(-center.dx, -center.dy));
    final rotation = Transform2D.rotationDeg(clockwise ? 90 : -90);
    final delta = pivot.multiply(rotation).multiply(unpivot);
    _commitTransformSelection(delta, nodes: nodes, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    final nodes = interaction_eligibility_policy
        .selectedTransformableNodesInSnapshotOrder(
          snapshot: mutationAccess.snapshot,
          selected: mutationAccess.selectedNodeIds,
        );
    if (nodes.isEmpty) {
      return;
    }

    final center = mutationAccess.centerWorldForNodeSnapshots(nodes);
    final delta = Transform2D(
      a: 1,
      b: 0,
      c: 0,
      d: -1,
      tx: 0,
      ty: 2 * center.dy,
    );
    _commitTransformSelection(delta, nodes: nodes, timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    final nodes = interaction_eligibility_policy
        .selectedTransformableNodesInSnapshotOrder(
          snapshot: mutationAccess.snapshot,
          selected: mutationAccess.selectedNodeIds,
        );
    if (nodes.isEmpty) {
      return;
    }

    final center = mutationAccess.centerWorldForNodeSnapshots(nodes);
    final delta = Transform2D(
      a: -1,
      b: 0,
      c: 0,
      d: 1,
      tx: 2 * center.dx,
      ty: 0,
    );
    _commitTransformSelection(delta, nodes: nodes, timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    final deletedIds = interaction_eligibility_policy
        .deletableSelectedNodeIdsInSnapshot(
          snapshot: mutationAccess.snapshot,
          selected: mutationAccess.selectedNodeIds,
        );
    if (deletedIds.isEmpty) {
      return;
    }

    final removedCount = mutationAccess.deleteSelection();
    if (removedCount <= 0) {
      return;
    }
    _scheduleSceneCommit();

    callbacks.emitAction(
      ActionType.delete,
      deletedIds,
      callbacks.resolveTimestampMs(timestampMs),
    );
  }

  MoveCommitSelectionResult commitMoveSelection(Offset proposedDelta) {
    final result = mutationAccess.write<MoveCommitSelectionResult>((writer) {
      final snapshot = writer.snapshot;
      final movedNodes = interaction_eligibility_policy
          .selectedCommitMovableNodesInSnapshotOrder(
            snapshot: snapshot,
            selected: writer.selectedNodeIds,
          );
      if (movedNodes.isEmpty) {
        return (appliedDelta: Offset.zero, movedIds: const <NodeId>[]);
      }

      final resolvedDelta = callbacks.resolveMoveCommitDelta(
        snapshot: snapshot,
        movedNodes: movedNodes,
        proposedDelta: proposedDelta,
      );
      callbacks.requireFiniteOffset(resolvedDelta, name: 'resolvedDelta');
      if (resolvedDelta == Offset.zero) {
        return (appliedDelta: Offset.zero, movedIds: const <NodeId>[]);
      }

      final movedIds = <NodeId>[];
      for (final node in movedNodes) {
        final nextTransform = node.transform.withTranslation(
          node.transform.translation + resolvedDelta,
        );
        if (!writer.writeNodeTransformSet(node.id, nextTransform)) {
          continue;
        }
        movedIds.add(node.id);
      }
      if (movedIds.isEmpty) {
        return (appliedDelta: Offset.zero, movedIds: const <NodeId>[]);
      }

      return (appliedDelta: resolvedDelta, movedIds: movedIds);
    });
    if (result.appliedDelta != Offset.zero && result.movedIds.isNotEmpty) {
      _scheduleSceneCommit();
    }
    return result;
  }

  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  }) {
    final nodeId = mutationAccess.commitDrawStroke(
      points: points,
      thickness: thickness,
      color: color,
      opacity: opacity,
    );
    _scheduleSceneCommit();
    return nodeId;
  }

  NodeId commitDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  }) {
    final nodeId = mutationAccess.commitDrawLineFromWorldSegment(
      start: start,
      end: end,
      thickness: thickness,
      color: color,
      opacity: opacity,
    );
    _scheduleSceneCommit();
    return nodeId;
  }

  int commitEraseNodes(Iterable<NodeId> ids) {
    final removedCount = mutationAccess.commitEraseNodes(ids);
    if (removedCount > 0) {
      _scheduleSceneCommit();
    }
    return removedCount;
  }

  void _commitTransformSelection(
    Transform2D delta, {
    required List<NodeSnapshot> nodes,
    int? timestampMs,
  }) {
    final movedIds = nodes.map((node) => node.id).toList(growable: false);
    final affected = mutationAccess.transformSelection(delta);
    if (affected <= 0) {
      return;
    }
    _scheduleSceneCommit();

    callbacks.emitAction(
      ActionType.transform,
      movedIds,
      callbacks.resolveTimestampMs(timestampMs),
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
  }

  void _scheduleSceneCommit() {
    callbacks.schedulePublicNotify();
    callbacks.scheduleSceneRepaint();
  }

  void _scheduleSceneAndOverlayCommit() {
    callbacks.schedulePublicNotify();
    callbacks.scheduleSceneRepaint();
    callbacks.scheduleOverlayRepaint();
  }
}
