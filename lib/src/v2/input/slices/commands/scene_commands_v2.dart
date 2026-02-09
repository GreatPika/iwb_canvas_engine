import '../../../../core/nodes.dart';
import '../../../controller/scene_writer.dart';
import '../../../public/node_patch.dart';
import '../../../public/node_spec.dart';

class V2SceneCommandsSlice {
  V2SceneCommandsSlice(this._writeRunner);

  final T Function<T>(T Function(SceneWriter writer) fn) _writeRunner;

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
    _writeRunner((writer) {
      writer.writeSelectionReplace(nodeIds);
      writer.writeSignalEnqueue(type: 'selection.replaced', nodeIds: nodeIds);
      return null;
    });
  }

  void writeSelectionToggle(NodeId nodeId) {
    _writeRunner((writer) {
      writer.writeSelectionToggle(nodeId);
      writer.writeSignalEnqueue(
        type: 'selection.toggled',
        nodeIds: <NodeId>[nodeId],
      );
      return null;
    });
  }
}
