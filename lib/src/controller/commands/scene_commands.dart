import 'dart:ui' show Color, Offset;

import '../../core/nodes.dart';
import '../../contract/ids.dart' show LayerId;
import '../../contract/transform2d.dart';
import '../../contract/node_patch.dart';
import '../../contract/node_spec.dart';
import '../../contract/scene_write_txn.dart';
import '../scene_writer.dart';

class SceneCommands {
  SceneCommands(this._writeRunner);

  final T Function<T>(T Function(SceneWriteTxn writer) fn) _writeRunner;

  List<NodeId> _sortedNodeIds(Iterable<NodeId> nodeIds) {
    final sorted = nodeIds.toList(growable: false);
    sorted.sort((a, b) => a.compareTo(b));
    return sorted;
  }

  SceneWriter _sceneWriter(SceneWriteTxn writer) {
    return writer as SceneWriter;
  }

  NodeId writeAddNode(NodeSpec spec, {LayerId? layerId, int? insertIndex}) {
    return _writeRunner((writer) {
      final nodeId = writer.writeNodeInsert(
        spec,
        layerId: layerId,
        insertIndex: insertIndex,
      );
      _sceneWriter(
        writer,
      ).writeOwnedSignalEnqueue(type: 'node.added', nodeIds: <NodeId>[nodeId]);
      return nodeId;
    });
  }

  bool writePatchNode(NodePatch patch) {
    return _writeRunner((writer) {
      final changed = writer.writeNodePatch(patch);
      if (changed) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(
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
        _sceneWriter(writer).writeOwnedSignalEnqueue(
          type: 'node.removed',
          nodeIds: <NodeId>[nodeId],
        );
      }
      return deleted;
    });
  }

  void writeSelectionReplace(Iterable<NodeId> nodeIds) {
    _writeRunner<void>((writer) {
      final sortedNodeIds = _sceneWriter(
        writer,
      ).writeSelectionReplaceResult(nodeIds);
      if (sortedNodeIds != null) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(
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
        _sceneWriter(writer).writeOwnedSignalEnqueue(
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
        _sceneWriter(writer).writeOwnedSignalEnqueue(type: 'selection.cleared');
      }
    });
  }

  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return _writeRunner((writer) {
      final result = _sceneWriter(
        writer,
      ).writeSelectionSelectAllResult(onlySelectable: onlySelectable);
      if (result.changed) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(type: 'selection.all');
      }
      return result.selectedCount;
    });
  }

  int writeSelectionTransform(Transform2D delta) {
    return _writeRunner((writer) {
      final affected = writer.writeSelectionTransform(delta);
      if (affected > 0) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(
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
        _sceneWriter(writer).writeOwnedSignalEnqueue(type: 'selection.deleted');
      }
      return removed;
    });
  }

  int writeClearScene() {
    return _writeRunner((writer) {
      final clearResult = writer.writeClearSceneKeepBackgroundResult();
      final removedNodeIds = clearResult.removedNodeIds;
      if (removedNodeIds.isNotEmpty || clearResult.didStructuralClear) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(
          type: 'scene.cleared',
          nodeIds: removedNodeIds,
        );
      }
      return removedNodeIds.length;
    });
  }

  void writeBackgroundColorSet(Color color) {
    _writeRunner<void>((writer) {
      if (_sceneWriter(writer).writeBackgroundColorChanged(color)) {
        _sceneWriter(
          writer,
        ).writeOwnedSignalEnqueue(type: 'background.updated');
      }
    });
  }

  void writeGridEnabledSet(bool enabled) {
    _writeRunner<void>((writer) {
      if (_sceneWriter(writer).writeGridEnableChanged(enabled)) {
        _sceneWriter(
          writer,
        ).writeOwnedSignalEnqueue(type: 'grid.enabled.updated');
      }
    });
  }

  void writeGridCellSizeSet(double size) {
    _writeRunner<void>((writer) {
      if (_sceneWriter(writer).writeGridCellSizeChanged(size)) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(type: 'grid.cell.updated');
      }
    });
  }

  void writeCameraOffsetSet(Offset offset) {
    _writeRunner<void>((writer) {
      if (_sceneWriter(writer).writeCameraOffsetChanged(offset)) {
        _sceneWriter(writer).writeOwnedSignalEnqueue(type: 'camera.updated');
      }
    });
  }
}
