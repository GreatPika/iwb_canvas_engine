import 'dart:ui';

import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_write_txn.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_controller.dart';
import '../../core/action_events.dart';
import '../../core/grid_safety_limits.dart';
import '../../model/document.dart' show txnSceneFromSnapshot;

final class SceneControllerSceneMutations {
  const SceneControllerSceneMutations({
    required this.core,
    required this.emitAction,
    required this.resolveTimestampMs,
    required this.resetInteractiveState,
    required this.clearPointerNormalizationState,
    required this.clearSceneSelectionState,
    required this.readSnapshot,
  });

  final SceneControllerCore core;
  final void Function(ActionType action, List<NodeId> nodeIds, int timestampMs)
  emitAction;
  final int Function(int? timestampMs) resolveTimestampMs;
  final VoidCallback resetInteractiveState;
  final VoidCallback clearPointerNormalizationState;
  final void Function({int? timestampMs}) clearSceneSelectionState;
  final SceneSnapshot Function() readSnapshot;

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
    if (!deleted) return false;
    emitAction(ActionType.delete, <NodeId>[
      id,
    ], resolveTimestampMs(timestampMs));
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

  void setCameraOffset(Offset value) {
    _requireFiniteOffset(value, name: 'value');
    if (readSnapshot().camera.offset == value) {
      return;
    }
    resetInteractiveState();
    core.commands.writeCameraOffsetSet(value);
  }

  void clearScene({int? timestampMs}) {
    clearSceneSelectionState(timestampMs: timestampMs);
  }

  void replaceScene(SceneSnapshot snapshot) {
    txnSceneFromSnapshot(snapshot);
    resetInteractiveState();
    core.writeReplaceScene(snapshot);
    clearPointerNormalizationState();
  }

  void notifySceneChanged() {
    core.requestRepaint();
  }
}

double _requireFinitePositive(double value, {required String name}) {
  if (value.isFinite && value > 0) return value;
  throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
}

void _requireFiniteOffset(Offset value, {required String name}) {
  if (value.dx.isFinite && value.dy.isFinite) return;
  throw ArgumentError.value(value, name, 'Offset must be finite.');
}
