import 'dart:ui' show Color, Offset;

import '../../core/nodes.dart';
import '../../core/transform2d.dart';
import '../../public/node_patch.dart';
import '../../public/node_spec.dart';
import '../../public/scene_write_txn.dart';

class SceneCommands {
  SceneCommands(this._writeRunner);

  final T Function<T>(T Function(SceneWriteTxn writer) fn) _writeRunner;

  List<NodeId> _sortedNodeIds(Iterable<NodeId> nodeIds) {
    final sorted = nodeIds.toList(growable: false);
    sorted.sort((a, b) => a.compareTo(b));
    return sorted;
  }

  String writeAddNode(NodeSpec spec, {int? layerIndex}) {
    return _writeRunner((writer) {
      final nodeId = writer.writeNodeInsert(spec, layerIndex: layerIndex);
      writer.writeSignalEnqueue(type: 'node.added', nodeIds: <NodeId>[nodeId]);
      return nodeId;
    });
  }

  bool writePatchNode(NodePatch patch) {
    return _writeRunner((writer) {
      final changed = writer.writeNodePatch(patch);
      if (changed) {
        writer.writeSignalEnqueue(
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
        writer.writeSignalEnqueue(
          type: 'node.removed',
          nodeIds: <NodeId>[nodeId],
        );
      }
      return deleted;
    });
  }

  void writeSelectionReplace(Iterable<NodeId> nodeIds) {
    _writeRunner<void>((writer) {
      final changed = writer.writeSelectionReplace(nodeIds);
      if (changed) {
        final sortedNodeIds = _sortedNodeIds(writer.selectedNodeIds);
        writer.writeSignalEnqueue(
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
        writer.writeSignalEnqueue(
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
        writer.writeSignalEnqueue(type: 'selection.cleared');
      }
    });
  }

  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return _writeRunner((writer) {
      final count = writer.writeSelectionSelectAll(
        onlySelectable: onlySelectable,
      );
      if (count > 0) {
        writer.writeSignalEnqueue(type: 'selection.all');
      }
      return count;
    });
  }

  int writeSelectionTransform(Transform2D delta) {
    return _writeRunner((writer) {
      final affected = writer.writeSelectionTransform(delta);
      if (affected > 0) {
        writer.writeSignalEnqueue(
          type: 'selection.transformed',
          payload: <String, Object?>{'delta': delta.toJsonMap()},
        );
      }
      return affected;
    });
  }

  int writeDeleteSelection() {
    return _writeRunner((writer) {
      final removed = writer.writeDeleteSelection();
      if (removed > 0) {
        writer.writeSignalEnqueue(type: 'selection.deleted');
      }
      return removed;
    });
  }

  int writeClearScene() {
    return _writeRunner((writer) {
      final removedIds = writer.writeClearSceneKeepBackground();
      if (removedIds.isNotEmpty) {
        writer.writeSignalEnqueue(type: 'scene.cleared', nodeIds: removedIds);
      }
      return removedIds.length;
    });
  }

  void writeBackgroundColorSet(Color color) {
    _writeRunner<void>((writer) {
      writer.writeBackgroundColor(color);
      writer.writeSignalEnqueue(type: 'background.updated');
    });
  }

  void writeGridEnabledSet(bool enabled) {
    _writeRunner<void>((writer) {
      writer.writeGridEnable(enabled);
      writer.writeSignalEnqueue(type: 'grid.enabled.updated');
    });
  }

  void writeGridCellSizeSet(double size) {
    _writeRunner<void>((writer) {
      writer.writeGridCellSize(size);
      writer.writeSignalEnqueue(type: 'grid.cell.updated');
    });
  }

  void writeCameraOffsetSet(Offset offset) {
    _writeRunner<void>((writer) {
      writer.writeCameraOffset(offset);
      writer.writeSignalEnqueue(type: 'camera.updated');
    });
  }
}
