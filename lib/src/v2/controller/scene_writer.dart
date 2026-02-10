import 'dart:ui';

import '../../core/background_layer_invariants.dart';
import '../../core/nodes.dart';
import '../../core/scene.dart';
import '../../core/selection_policy.dart';
import '../../core/transform2d.dart';
import '../input/slices/signals/signal_event.dart';
import '../model/document_clone.dart';
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

  NodeId writeNewNodeId() => _ctx.txnNextNodeId();

  bool writeContainsNodeId(NodeId nodeId) => _ctx.txnHasNodeId(nodeId);

  void writeRegisterNodeId(NodeId nodeId) {
    _ctx.txnRememberNodeId(nodeId);
  }

  void writeUnregisterNodeId(NodeId nodeId) {
    _ctx.txnForgetNodeId(nodeId);
  }

  void writeRebuildNodeIdIndex() {
    _ctx.workingNodeIds = txnCollectNodeIds(_ctx.workingScene);
  }

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

  ({SceneNode node, int layerIndex, int nodeIndex})? writeFindNode(NodeId id) {
    return txnFindNodeById(_ctx.workingScene, id);
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

  bool writeSelectionClear() {
    if (_ctx.workingSelection.isEmpty) {
      return false;
    }
    _ctx.workingSelection = <NodeId>{};
    _ctx.changeSet.txnMarkSelectionChanged();
    return true;
  }

  int writeSelectionSelectAll({bool onlySelectable = true}) {
    final ids = <NodeId>{
      for (final layer in _ctx.workingScene.layers)
        for (final node in layer.nodes)
          if (isNodeInteractiveForSelection(
            node,
            layer,
            onlySelectable: onlySelectable,
          ))
            node.id,
    };
    if (_txnSetsEqual(_ctx.workingSelection, ids)) {
      return 0;
    }
    _ctx.workingSelection = ids;
    _ctx.changeSet.txnMarkSelectionChanged();
    return ids.length;
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

  int writeSelectionTransform(Transform2D delta) {
    final selected = _ctx.workingSelection;
    if (selected.isEmpty) return 0;

    var affected = 0;
    for (final layer in _ctx.workingScene.layers) {
      if (layer.isBackground) continue;
      for (final node in layer.nodes) {
        if (!selected.contains(node.id)) continue;
        if (!node.isTransformable || node.isLocked) continue;
        final before = node.boundsWorld;
        node.transform = delta.multiply(node.transform);
        final after = node.boundsWorld;
        _ctx.changeSet.txnTrackUpdated(node.id);
        if (before != after) {
          _ctx.changeSet.txnMarkBoundsChanged();
        } else {
          _ctx.changeSet.txnMarkVisualChanged();
        }
        affected = affected + 1;
      }
    }
    return affected;
  }

  int writeDeleteSelection() {
    final selected = _ctx.workingSelection;
    if (selected.isEmpty) return 0;

    final deleted = <NodeId>{
      for (final layer in _ctx.workingScene.layers)
        for (final node in layer.nodes)
          if (selected.contains(node.id) && isNodeDeletableInLayer(node, layer))
            node.id,
    };
    if (deleted.isEmpty) return 0;

    for (final id in deleted) {
      _ctx.txnForgetNodeId(id);
    }

    for (final layer in _ctx.workingScene.layers) {
      layer.nodes.retainWhere((node) => !deleted.contains(node.id));
    }
    _ctx.changeSet.txnMarkStructuralChanged();
    for (final id in deleted) {
      _ctx.changeSet.txnTrackRemoved(id);
    }
    _ctx.workingSelection = <NodeId>{
      for (final id in _ctx.workingSelection)
        if (!deleted.contains(id)) id,
    };
    _ctx.changeSet.txnMarkSelectionChanged();
    return deleted.length;
  }

  List<NodeId> writeClearSceneKeepBackground() {
    canonicalizeBackgroundLayerInvariants(
      _ctx.workingScene.layers,
      onMultipleBackgroundError: (count) {
        throw StateError(
          'clearScene requires at most one background layer; found $count.',
        );
      },
    );

    final layers = _ctx.workingScene.layers;
    final clearedIds = <NodeId>[
      for (var layerIndex = 1; layerIndex < layers.length; layerIndex++)
        for (final node in layers[layerIndex].nodes) node.id,
    ];
    for (final id in clearedIds) {
      _ctx.txnForgetNodeId(id);
    }
    if (layers.length > 1) {
      layers.length = 1;
    }
    if (clearedIds.isEmpty) {
      return const <NodeId>[];
    }

    _ctx.changeSet.txnMarkStructuralChanged();
    for (final id in clearedIds) {
      _ctx.changeSet.txnTrackRemoved(id);
    }
    if (_ctx.workingSelection.isNotEmpty) {
      _ctx.workingSelection = <NodeId>{};
      _ctx.changeSet.txnMarkSelectionChanged();
    }
    return clearedIds;
  }

  void writeCameraOffset(Offset offset) {
    if (_ctx.workingScene.camera.offset == offset) return;
    _ctx.workingScene.camera.offset = offset;
    _ctx.changeSet.txnMarkVisualChanged();
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

  void writeMarkSceneStructuralChanged() {
    _ctx.changeSet.txnMarkStructuralChanged();
  }

  void writeMarkSceneGeometryChanged() {
    _ctx.changeSet.txnMarkBoundsChanged();
  }

  void writeMarkVisualChanged() {
    _ctx.changeSet.txnMarkVisualChanged();
  }

  void writeMarkSelectionChanged() {
    _ctx.changeSet.txnMarkSelectionChanged();
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
