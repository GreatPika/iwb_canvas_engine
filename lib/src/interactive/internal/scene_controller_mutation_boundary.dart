import 'dart:ui';

import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_write_txn.dart';
import '../../contract/snapshot.dart';
import '../../contract/transform2d.dart';
import '../../controller/scene_controller.dart';
import '../../core/action_events.dart';
import '../../core/grid_safety_limits.dart';
import '../../controller/scene_snapshot_materializer.dart';
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
}

final class SceneControllerMutationBoundary {
  const SceneControllerMutationBoundary({
    required this.core,
    required this.readSnapshot,
    required this.callbacks,
  });

  final SceneControllerCore core;
  final SceneSnapshot Function() readSnapshot;
  final SceneControllerMutationBoundaryCallbacks callbacks;

  T write<T>(T Function(SceneWriteTxn writer) fn) {
    return core.write(fn);
  }

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    return core.commands.writeAddNode(
      node,
      layerId: layerId,
      insertIndex: insertIndex,
    );
  }

  bool ensureLayer(LayerId layerId, {int? index}) {
    return core.write((writer) {
      return writer.writeLayerEnsure(layerId, index: index);
    });
  }

  bool patchNode(NodePatch patch) {
    return core.commands.writePatchNode(patch);
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    final deleted = core.commands.writeDeleteNode(id);
    if (!deleted) {
      return false;
    }
    callbacks.emitAction(ActionType.delete, <NodeId>[
      id,
    ], callbacks.resolveTimestampMs(timestampMs));
    return true;
  }

  void setBackgroundColor(Color value) {
    core.commands.writeBackgroundColorSet(value);
  }

  void setGridEnabled(bool value) {
    core.commands.writeGridEnabledSet(value);
  }

  void setGridCellSize(double value) {
    _requireFinitePositive(value, name: 'cellSize');
    final gridEnabled = readSnapshot().background.grid.isEnabled;
    final resolved = gridEnabled
        ? value.clamp(kMinGridCellSize, double.infinity).toDouble()
        : value;
    core.commands.writeGridCellSizeSet(resolved);
  }

  void validateCameraOffset(Offset value) {
    callbacks.requireFiniteOffset(value, name: 'value');
  }

  bool shouldApplyCameraOffset(Offset value) {
    return readSnapshot().camera.offset != value;
  }

  void setCameraOffset(Offset value) {
    core.commands.writeCameraOffsetSet(value);
  }

  void clearScene({int? timestampMs}) {
    final clearResult = core.write<({List<NodeId> clearedIds, bool changed})>((
      writer,
    ) {
      final result = writer.writeClearSceneKeepBackgroundResult();
      return (
        clearedIds: result.removedNodeIds,
        changed: result.didStructuralClear,
      );
    });
    if (!clearResult.changed) {
      return;
    }

    callbacks.emitAction(
      ActionType.clear,
      clearResult.clearedIds,
      callbacks.resolveTimestampMs(timestampMs),
    );
  }

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) {
    return core.prepareSceneReplacement(snapshot);
  }

  void replaceScene(PreparedSceneReplacement replacement) {
    core.writePreparedSceneReplacement(replacement);
    callbacks.clearPointerNormalizationState();
  }

  void notifySceneChanged() {
    core.requestRepaint();
  }

  void setSelection(Iterable<NodeId> nodeIds) {
    core.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    core.commands.writeSelectionToggle(nodeId);
  }

  void clearSelection() {
    core.commands.writeSelectionClear();
  }

  void selectAll({bool onlySelectable = true}) {
    core.commands.writeSelectionSelectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    final nodes = interaction_eligibility_policy
        .selectedTransformableNodesInSnapshotOrder(
          snapshot: core.snapshot,
          selected: core.selectedNodeIds,
        );
    if (nodes.isEmpty) {
      return;
    }

    final center = core.centerWorldForNodeSnapshots(nodes);
    final pivot = Transform2D.translation(center);
    final unpivot = Transform2D.translation(Offset(-center.dx, -center.dy));
    final rotation = Transform2D.rotationDeg(clockwise ? 90 : -90);
    final delta = pivot.multiply(rotation).multiply(unpivot);
    _commitTransformSelection(delta, nodes: nodes, timestampMs: timestampMs);
  }

  void flipSelectionVertical({int? timestampMs}) {
    final nodes = interaction_eligibility_policy
        .selectedTransformableNodesInSnapshotOrder(
          snapshot: core.snapshot,
          selected: core.selectedNodeIds,
        );
    if (nodes.isEmpty) {
      return;
    }

    final center = core.centerWorldForNodeSnapshots(nodes);
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
          snapshot: core.snapshot,
          selected: core.selectedNodeIds,
        );
    if (nodes.isEmpty) {
      return;
    }

    final center = core.centerWorldForNodeSnapshots(nodes);
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
          snapshot: core.snapshot,
          selected: core.selectedNodeIds,
        );
    if (deletedIds.isEmpty) {
      return;
    }

    final removedCount = core.commands.writeDeleteSelection();
    if (removedCount <= 0) {
      return;
    }

    callbacks.emitAction(
      ActionType.delete,
      deletedIds,
      callbacks.resolveTimestampMs(timestampMs),
    );
  }

  MoveCommitSelectionResult commitMoveSelection(Offset proposedDelta) {
    return core.write<MoveCommitSelectionResult>((writer) {
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
  }

  void _commitTransformSelection(
    Transform2D delta, {
    required List<NodeSnapshot> nodes,
    int? timestampMs,
  }) {
    final movedIds = nodes.map((node) => node.id).toList(growable: false);
    final affected = core.commands.writeSelectionTransform(delta);
    if (affected <= 0) {
      return;
    }

    callbacks.emitAction(
      ActionType.transform,
      movedIds,
      callbacks.resolveTimestampMs(timestampMs),
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
  }
}

double _requireFinitePositive(double value, {required String name}) {
  if (value.isFinite && value > 0) {
    return value;
  }
  throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
}
