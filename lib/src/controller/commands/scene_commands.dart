import 'dart:ui' show Color, Offset;

import '../../core/nodes.dart';
import '../../contract/ids.dart' show LayerId;
import '../../contract/transform2d.dart';
import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
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

  void writeSelectionReplace(Iterable<NodeId> nodeIds) {
    _writeRunner<void>((writer) {
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
    });
  }

  void writeSelectionToggle(NodeId nodeId) {
    _writeRunner<void>((writer) {
      final changed = writer.writeSelectionToggle(nodeId);
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.toggled',
          nodeIds: _sortedNodeIds(<NodeId>[nodeId]),
        );
      }
    });
  }

  void writeSelectionClear() {
    _writeRunner<void>((writer) {
      final changed = writer.writeSelectionClear();
      if (changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'selection.cleared',
        );
      }
    });
  }

  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return _writeRunner((writer) {
      final result = sceneWriterWriteSelectionSelectAllExactResult(
        writer,
        onlySelectable: onlySelectable,
      );
      if (result.changed) {
        sceneWriterWriteOwnedSignalExactEnqueue(writer, type: 'selection.all');
      }
      return result.selectedCount;
    });
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

  int writeClearScene() {
    return _writeRunner((writer) {
      final clearResult = writer.writeClearSceneKeepBackgroundResult();
      final removedNodeIds = clearResult.removedNodeIds;
      if (removedNodeIds.isNotEmpty || clearResult.didStructuralClear) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'scene.cleared',
          nodeIds: removedNodeIds,
        );
      }
      return removedNodeIds.length;
    });
  }

  void writeBackgroundColorSet(Color color) {
    _writeRunner<void>((writer) {
      if (sceneWriterWriteBackgroundColorExactChange(writer, color)) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'background.updated',
        );
      }
    });
  }

  void writeGridEnabledSet(bool enabled) {
    _writeRunner<void>((writer) {
      if (sceneWriterWriteGridEnableExactChange(writer, enabled)) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'grid.enabled.updated',
        );
      }
    });
  }

  void writeGridCellSizeSet(double size) {
    _writeRunner<void>((writer) {
      if (sceneWriterWriteGridCellSizeExactChange(writer, size)) {
        sceneWriterWriteOwnedSignalExactEnqueue(
          writer,
          type: 'grid.cell.updated',
        );
      }
    });
  }

  void writeCameraOffsetSet(Offset offset) {
    _writeRunner<void>((writer) {
      if (sceneWriterWriteCameraOffsetExactChange(writer, offset)) {
        sceneWriterWriteOwnedSignalExactEnqueue(writer, type: 'camera.updated');
      }
    });
  }
}
