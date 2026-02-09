import 'dart:ui';

import '../../core/nodes.dart';
import '../../core/scene.dart';
import '../input/slices/signals/signal_event.dart';
import '../model/document.dart';
import '../public/node_patch.dart';
import '../public/node_spec.dart';
import '../public/snapshot.dart' hide NodeId;
import 'txn_context.dart';

class SceneWriter {
  SceneWriter(this._ctx, {required this.txnSignalSink});

  final TxnContext _ctx;
  final void Function(V2BufferedSignal signal) txnSignalSink;

  Scene get scene => _ctx.workingScene;
  Set<NodeId> get selectedNodeIds => _ctx.workingSelection;

  String writeNodeInsert(NodeSpec spec, {int? layerIndex}) {
    final resolvedId = spec.id ?? _ctx.txnNextNodeId();
    if (spec.id != null && _ctx.txnHasNodeId(resolvedId)) {
      throw StateError('Node id must be unique: $resolvedId');
    }

    final node = txnNodeFromSpec(spec, fallbackId: resolvedId);
    txnInsertNodeInScene(
      scene: _ctx.workingScene,
      node: node,
      layerIndex: layerIndex,
    );
    _ctx.txnRememberNodeId(node.id);
    _ctx.changeSet.txnMarkStructuralChanged();
    _ctx.changeSet.txnTrackAdded(node.id);
    return node.id;
  }

  bool writeNodeErase(NodeId nodeId) {
    final removed = txnEraseNodeFromScene(
      scene: _ctx.workingScene,
      nodeId: nodeId,
    );
    if (removed == null) {
      return false;
    }

    final hadSelection = _ctx.workingSelection.contains(nodeId);
    _ctx.workingSelection = <NodeId>{
      for (final id in _ctx.workingSelection)
        if (id != nodeId) id,
    };
    _ctx.txnForgetNodeId(nodeId);
    _ctx.changeSet.txnMarkStructuralChanged();
    _ctx.changeSet.txnTrackRemoved(nodeId);
    if (hadSelection) {
      _ctx.changeSet.txnMarkSelectionChanged();
    }
    return true;
  }

  bool writeNodePatch(NodePatch patch) {
    final found = txnFindNodeById(_ctx.workingScene, patch.id);
    if (found == null) {
      return false;
    }

    final oldBounds = found.node.boundsWorld;
    final changed = txnApplyNodePatch(found.node, patch);
    if (!changed) {
      return false;
    }

    _ctx.changeSet.txnTrackUpdated(patch.id);
    _ctx.changeSet.txnMarkVisualChanged();
    if (oldBounds != found.node.boundsWorld) {
      _ctx.changeSet.txnMarkBoundsChanged();
    }
    return true;
  }

  void writeSelectionReplace(Iterable<NodeId> ids) {
    final next = <NodeId>{for (final id in ids) id};
    if (_txnSetsEqual(_ctx.workingSelection, next)) {
      return;
    }
    _ctx.workingSelection = next;
    _ctx.changeSet.txnMarkSelectionChanged();
  }

  void writeSelectionToggle(NodeId id) {
    final contains = _ctx.workingSelection.contains(id);
    final next = contains
        ? <NodeId>{
            for (final candidate in _ctx.workingSelection)
              if (candidate != id) candidate,
          }
        : <NodeId>{..._ctx.workingSelection, id};
    if (_txnSetsEqual(_ctx.workingSelection, next)) {
      return;
    }
    _ctx.workingSelection = next;
    _ctx.changeSet.txnMarkSelectionChanged();
  }

  int writeSelectionTranslate(Offset delta) {
    final moved = txnTranslateSelection(
      scene: _ctx.workingScene,
      selectedNodeIds: _ctx.workingSelection,
      delta: delta,
    );
    if (moved.isEmpty) {
      return 0;
    }
    for (final nodeId in moved) {
      _ctx.changeSet.txnTrackUpdated(nodeId);
    }
    _ctx.changeSet.txnMarkBoundsChanged();
    return moved.length;
  }

  void writeGridEnable(bool enabled) {
    if (_ctx.workingScene.background.grid.isEnabled == enabled) {
      return;
    }
    _ctx.workingScene.background.grid.isEnabled = enabled;
    _ctx.changeSet.txnMarkGridChanged();
  }

  void writeGridCellSize(double cellSize) {
    if (_ctx.workingScene.background.grid.cellSize == cellSize) {
      return;
    }
    _ctx.workingScene.background.grid.cellSize = cellSize;
    _ctx.changeSet.txnMarkGridChanged();
  }

  void writeBackgroundColor(Color color) {
    if (_ctx.workingScene.background.color == color) {
      return;
    }
    _ctx.workingScene.background.color = color;
    _ctx.changeSet.txnMarkVisualChanged();
  }

  void writeDocumentReplace(SceneSnapshot snapshot) {
    final previousSelection = _ctx.workingSelection;
    final nextScene = txnSceneFromSnapshot(snapshot);
    _ctx.txnAdoptScene(nextScene);
    _ctx.workingSelection = <NodeId>{};
    _ctx.changeSet.txnMarkDocumentReplaced();
    if (previousSelection.isNotEmpty) {
      _ctx.changeSet.txnMarkSelectionChanged();
    }
  }

  void writeSignalEnqueue({
    required String type,
    Iterable<NodeId> nodeIds = const <NodeId>[],
    Map<String, Object?>? payload,
  }) {
    txnSignalSink(
      V2BufferedSignal(
        type: type,
        nodeIds: List<NodeId>.of(nodeIds),
        payload: payload,
      ),
    );
  }

  bool _txnSetsEqual(Set<NodeId> left, Set<NodeId> right) {
    return left.length == right.length && left.containsAll(right);
  }
}
