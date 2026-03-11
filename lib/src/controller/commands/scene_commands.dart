import 'dart:ui' show Color, Offset;

import '../../core/nodes.dart';
import '../../contract/ids.dart' show LayerId;
import '../../contract/transform2d.dart';
import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
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
      writer.writeOwnedSignalEnqueue(
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
        writer.writeOwnedSignalEnqueue(
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
        writer.writeOwnedSignalEnqueue(
          type: 'node.removed',
          nodeIds: <NodeId>[nodeId],
        );
      }
      return deleted;
    });
  }

  void writeSelectionReplace(Iterable<NodeId> nodeIds) {
    _writeRunner<void>((writer) {
      final sortedNodeIds = writer.writeSelectionReplaceResult(nodeIds);
      if (sortedNodeIds != null) {
        writer.writeOwnedSignalEnqueue(
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
        writer.writeOwnedSignalEnqueue(
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
        writer.writeOwnedSignalEnqueue(type: 'selection.cleared');
      }
    });
  }

  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return _writeRunner((writer) {
      final result = writer.writeSelectionSelectAllResult(
        onlySelectable: onlySelectable,
      );
      if (result.changed) {
        writer.writeOwnedSignalEnqueue(type: 'selection.all');
      }
      return result.selectedCount;
    });
  }

  int writeSelectionTransform(Transform2D delta) {
    return _writeRunner((writer) {
      final affected = writer.writeSelectionTransform(delta);
      if (affected > 0) {
        writer.writeOwnedSignalEnqueue(
          type: 'selection.transformed',
          payload: <String, Object?>{'delta': delta.toJsonMap()},
        );
      }
      return affected;
    });
  }

  int writeDeleteSelection() {
    return _writeRunner((writer) {
      final removedIds = writer.writeDeleteSelectionResult();
      if (removedIds.isNotEmpty) {
        writer.writeOwnedSignalEnqueue(
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
        writer.writeOwnedSignalEnqueue(
          type: 'scene.cleared',
          nodeIds: removedNodeIds,
        );
      }
      return removedNodeIds.length;
    });
  }

  void writeBackgroundColorSet(Color color) {
    _writeRunner<void>((writer) {
      if (writer.writeBackgroundColorChanged(color)) {
        writer.writeOwnedSignalEnqueue(type: 'background.updated');
      }
    });
  }

  void writeGridEnabledSet(bool enabled) {
    _writeRunner<void>((writer) {
      if (writer.writeGridEnableChanged(enabled)) {
        writer.writeOwnedSignalEnqueue(type: 'grid.enabled.updated');
      }
    });
  }

  void writeGridCellSizeSet(double size) {
    _writeRunner<void>((writer) {
      if (writer.writeGridCellSizeChanged(size)) {
        writer.writeOwnedSignalEnqueue(type: 'grid.cell.updated');
      }
    });
  }

  void writeCameraOffsetSet(Offset offset) {
    _writeRunner<void>((writer) {
      if (writer.writeCameraOffsetChanged(offset)) {
        writer.writeOwnedSignalEnqueue(type: 'camera.updated');
      }
    });
  }
}
