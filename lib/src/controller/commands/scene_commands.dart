import 'dart:ui' show Color, Offset;

import '../../core/nodes.dart';
import '../../contract/ids.dart' show LayerId;
import '../../contract/transform2d.dart';
import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_write_txn.dart';
import '../scene_writer_command_results.dart';
import '../scene_writer.dart';

typedef SceneCommandRunner = T Function<T>(T Function(SceneWriter writer) fn);

class SceneCommands {
  SceneCommands(this._writeRunner);

  final SceneCommandRunner _writeRunner;

  List<NodeId> _sortedNodeIds(Iterable<NodeId> nodeIds) {
    final sorted = nodeIds.toList(growable: false);
    sorted.sort((a, b) => a.compareTo(b));
    return sorted;
  }

  NodeId writeAddNode(NodeSpec spec, {LayerId? layerId, int? insertIndex}) {
    return _writeRunner((writer) {
      final nodeId = writer.writeNodeInsert(
        spec,
        layerId: layerId,
        insertIndex: insertIndex,
      );
      sceneWriterWriteOwnedSignalExactEnqueue(
        writer,
        type: 'node.added',
        nodeIds: <NodeId>[nodeId],
      );
      return nodeId;
    });
  }

  bool writePatchNode(NodePatch patch) {
    return _writeRunner((writer) {
      final changed = writer.writeNodePatch(patch);
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'node.updated',
          nodeIds: <NodeId>[patch.id],
        );
      }
      return changed;
    });
  }

  bool writeDeleteNode(NodeId nodeId) {
    return _writeRunner((writer) {
      final deleted = writer.writeNodeErase(nodeId);
      if (deleted) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'node.removed',
          nodeIds: <NodeId>[nodeId],
        );
      }
      return deleted;
    });
  }

  List<NodeId>? writeSelectionReplaceExactResult(Iterable<NodeId> nodeIds) {
    return _writeRunner<List<NodeId>?>((writer) {
      final sortedNodeIds = sceneWriterWriteSelectionReplaceExactResult(
        writer,
        nodeIds,
      );
      if (sortedNodeIds != null) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.replaced',
          nodeIds: sortedNodeIds,
        );
      }
      return sortedNodeIds;
    });
  }

  void writeSelectionReplace(Iterable<NodeId> nodeIds) {
    writeSelectionReplaceExactResult(nodeIds);
  }

  bool writeSelectionToggleExactChange(NodeId nodeId) {
    return _writeRunner<bool>((writer) {
      final changed = writer.writeSelectionToggle(nodeId);
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.toggled',
          nodeIds: _sortedNodeIds(<NodeId>[nodeId]),
        );
      }
      return changed;
    });
  }

  void writeSelectionToggle(NodeId nodeId) {
    writeSelectionToggleExactChange(nodeId);
  }

  bool writeSelectionClearExactChange() {
    return _writeRunner<bool>((writer) {
      final changed = writer.writeSelectionClear();
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.cleared',
        );
      }
      return changed;
    });
  }

  void writeSelectionClear() {
    writeSelectionClearExactChange();
  }

  ({int selectedCount, bool changed}) writeSelectionSelectAllExactResult({
    bool onlySelectable = true,
  }) {
    return _writeRunner<({int selectedCount, bool changed})>((writer) {
      final result = sceneWriterWriteSelectionSelectAllExactResult(
        writer,
        onlySelectable: onlySelectable,
      );
      if (result.changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(writer, type: 'selection.all');
      }
      return result;
    });
  }

  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return writeSelectionSelectAllExactResult(
      onlySelectable: onlySelectable,
    ).selectedCount;
  }

  int writeSelectionTransform(Transform2D delta) {
    return _writeRunner((writer) {
      final affected = writer.writeSelectionTransform(delta);
      if (affected > 0) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.transformed',
          payload: <String, Object?>{'delta': delta.toJsonMap()},
        );
      }
      return affected;
    });
  }

  int writeDeleteSelection() {
    return _writeRunner((writer) {
      final removedIds = sceneWriterWriteDeleteSelectionExactResult(writer);
      if (removedIds.isNotEmpty) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.deleted',
          nodeIds: removedIds,
        );
      }
      return removedIds.length;
    });
  }

  ClearSceneResult writeClearSceneExactResult() {
    return _writeRunner((writer) {
      final clearResult = sceneWriterWriteClearSceneExactResult(writer);
      final removedNodeIds = clearResult.removedNodeIds;
      if (removedNodeIds.isNotEmpty || clearResult.didStructuralClear) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'scene.cleared',
          nodeIds: removedNodeIds,
        );
      }
      return clearResult;
    });
  }

  int writeClearScene() {
    return writeClearSceneExactResult().removedNodeIds.length;
  }

  bool writeBackgroundColorSetExactChange(Color color) {
    return _writeRunner<bool>((writer) {
      final changed = sceneWriterWriteBackgroundColorExactChange(writer, color);
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'background.updated',
        );
      }
      return changed;
    });
  }

  void writeBackgroundColorSet(Color color) {
    writeBackgroundColorSetExactChange(color);
  }

  bool writeGridEnabledSetExactChange(bool enabled) {
    return _writeRunner<bool>((writer) {
      final changed = sceneWriterWriteGridEnableExactChange(writer, enabled);
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'grid.enabled.updated',
        );
      }
      return changed;
    });
  }

  void writeGridEnabledSet(bool enabled) {
    writeGridEnabledSetExactChange(enabled);
  }

  bool writeGridCellSizeSetExactChange(double size) {
    return _writeRunner<bool>((writer) {
      final changed = sceneWriterWriteGridCellSizeExactChange(writer, size);
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'grid.cell.updated',
        );
      }
      return changed;
    });
  }

  void writeGridCellSizeSet(double size) {
    writeGridCellSizeSetExactChange(size);
  }

  bool writeCameraOffsetSetExactChange(Offset offset) {
    return _writeRunner<bool>((writer) {
      final changed = sceneWriterWriteCameraOffsetExactChange(writer, offset);
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(writer, type: 'camera.updated');
      }
      return changed;
    });
  }

  void writeCameraOffsetSet(Offset offset) {
    writeCameraOffsetSetExactChange(offset);
  }
}
