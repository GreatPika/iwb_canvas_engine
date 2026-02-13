import 'dart:ui';

import '../core/background_layer_invariants.dart';
import '../core/hit_test.dart';
import '../core/selection_policy.dart';
import '../core/transform2d.dart';
import '../input/slices/signals/signal_event.dart';
import '../model/document.dart';
import '../public/node_patch.dart';
import '../public/node_spec.dart';
import '../public/scene_write_txn.dart';
import '../public/snapshot.dart';
import 'txn_context.dart';

class SceneWriter implements SceneWriteTxn {
  SceneWriter(this._ctx, {required this.txnSignalSink});

  final TxnContext _ctx;
  final void Function(V2BufferedSignal signal) txnSignalSink;

  @override
  SceneSnapshot get snapshot => txnSceneToSnapshot(_ctx.workingScene);

  @override
  Set<NodeId> get selectedNodeIds =>
      Set<NodeId>.unmodifiable(_ctx.workingSelection);

  @override
  String writeNodeInsert(NodeSpec spec, {int? layerIndex}) {
    final resolvedId = spec.id ?? _ctx.txnNextNodeId();
    if (spec.id != null && _ctx.txnHasNodeId(resolvedId)) {
      throw StateError('Node id must be unique: $resolvedId');
    }

    final node = txnNodeFromSpec(spec, fallbackId: resolvedId);
    final scene = _ctx.txnEnsureMutableScene();
    final targetLayerIndex = txnResolveInsertLayerIndex(
      scene: scene,
      layerIndex: layerIndex,
    );
    final layer = _ctx.txnEnsureMutableLayer(targetLayerIndex);
    layer.nodes.add(node);
    _ctx.txnRememberNodeId(node.id);
    _ctx.changeSet.txnMarkStructuralChanged();
    _ctx.changeSet.txnTrackAdded(node.id);
    return node.id;
  }

  @override
  bool writeNodeErase(NodeId nodeId) {
    final existing = txnFindNodeById(_ctx.workingScene, nodeId);
    if (existing == null) {
      return false;
    }
    final layer = _ctx.workingScene.layers[existing.layerIndex];
    if (!isNodeDeletableInLayer(existing.node, layer)) {
      return false;
    }
    _ctx.txnEnsureMutableLayer(existing.layerIndex);
    final scene = _ctx.txnEnsureMutableScene();
    final removed = txnEraseNodeFromScene(scene: scene, nodeId: nodeId);
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

  @override
  bool writeNodePatch(NodePatch patch) {
    final existing = txnFindNodeById(_ctx.workingScene, patch.id);
    if (existing == null) {
      return false;
    }
    if (!txnApplyNodePatch(existing.node, patch, dryRun: true)) {
      return false;
    }

    final found = _ctx.txnResolveMutableNode(patch.id);
    final oldCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    txnApplyNodePatch(found.node, patch);

    _ctx.changeSet.txnTrackUpdated(patch.id);
    final newCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    if (oldCandidate != newCandidate) {
      _ctx.changeSet.txnMarkBoundsChanged();
    } else {
      _ctx.changeSet.txnMarkVisualChanged();
    }
    if (_ctx.workingSelection.contains(patch.id) &&
        _txnPatchTouchesSelectionPolicy(patch)) {
      _ctx.changeSet.txnMarkSelectionChanged();
    }
    return true;
  }

  @override
  bool writeNodeTransformSet(NodeId id, Transform2D transform) {
    _txnRequireFiniteTransform(transform, name: 'transform');
    final existing = txnFindNodeById(_ctx.workingScene, id);
    if (existing == null) return false;
    if (existing.node.transform == transform) return false;

    final found = _ctx.txnResolveMutableNode(id);
    final oldCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    found.node.transform = transform;
    _ctx.changeSet.txnTrackUpdated(id);
    final newCandidate = nodeHitTestCandidateBoundsWorld(found.node);
    if (oldCandidate != newCandidate) {
      _ctx.changeSet.txnMarkBoundsChanged();
    } else {
      _ctx.changeSet.txnMarkVisualChanged();
    }
    return true;
  }

  @override
  void writeSelectionReplace(Iterable<NodeId> ids) {
    final next = <NodeId>{for (final id in ids) id};
    if (_txnSetsEqual(_ctx.workingSelection, next)) {
      return;
    }
    _ctx.workingSelection = next;
    _ctx.changeSet.txnMarkSelectionChanged();
  }

  @override
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

  @override
  bool writeSelectionClear() {
    if (_ctx.workingSelection.isEmpty) {
      return false;
    }
    _ctx.workingSelection = <NodeId>{};
    _ctx.changeSet.txnMarkSelectionChanged();
    return true;
  }

  @override
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

  @override
  int writeSelectionTranslate(Offset delta) {
    _txnRequireFiniteOffset(delta, name: 'delta');
    if (delta == Offset.zero || _ctx.workingSelection.isEmpty) {
      return 0;
    }

    final moved = <NodeId>{};
    final selectedIds = _ctx.workingSelection.toList(growable: false);
    for (final nodeId in selectedIds) {
      final existing = txnFindNodeById(_ctx.workingScene, nodeId);
      if (existing == null) continue;
      final layer = _ctx.workingScene.layers[existing.layerIndex];
      if (layer.isBackground) continue;
      if (existing.node.isLocked || !existing.node.isTransformable) continue;

      final mutable = _ctx.txnResolveMutableNode(nodeId);
      mutable.node.position = mutable.node.position + delta;
      moved.add(nodeId);
    }
    if (moved.isEmpty) return 0;

    for (final nodeId in moved) {
      _ctx.changeSet.txnTrackUpdated(nodeId);
    }
    _ctx.changeSet.txnMarkBoundsChanged();
    return moved.length;
  }

  @override
  int writeSelectionTransform(Transform2D delta) {
    _txnRequireFiniteTransform(delta, name: 'delta');
    final selected = _ctx.workingSelection;
    if (selected.isEmpty) return 0;

    var affected = 0;
    final selectedIds = selected.toList(growable: false);
    for (final nodeId in selectedIds) {
      final existing = txnFindNodeById(_ctx.workingScene, nodeId);
      if (existing == null) continue;
      final layer = _ctx.workingScene.layers[existing.layerIndex];
      if (layer.isBackground) continue;
      if (!existing.node.isTransformable || existing.node.isLocked) continue;

      final nextTransform = delta.multiply(existing.node.transform);
      if (nextTransform == existing.node.transform) continue;

      final mutable = _ctx.txnResolveMutableNode(nodeId);
      final beforeCandidate = nodeHitTestCandidateBoundsWorld(mutable.node);
      mutable.node.transform = nextTransform;
      final afterCandidate = nodeHitTestCandidateBoundsWorld(mutable.node);
      _ctx.changeSet.txnTrackUpdated(nodeId);
      if (beforeCandidate != afterCandidate) {
        _ctx.changeSet.txnMarkBoundsChanged();
      } else {
        _ctx.changeSet.txnMarkVisualChanged();
      }
      affected = affected + 1;
    }
    return affected;
  }

  @override
  int writeDeleteSelection() {
    final selected = _ctx.workingSelection;
    if (selected.isEmpty) return 0;

    final deleted = <NodeId>{};
    final deletedByLayer = <int, Set<NodeId>>{};
    final layers = _ctx.workingScene.layers;
    for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      final layer = layers[layerIndex];
      for (final node in layer.nodes) {
        if (!selected.contains(node.id)) continue;
        if (!isNodeDeletableInLayer(node, layer)) continue;
        deleted.add(node.id);
        deletedByLayer.putIfAbsent(layerIndex, () => <NodeId>{}).add(node.id);
      }
    }
    if (deleted.isEmpty) return 0;

    for (final id in deleted) {
      _ctx.txnForgetNodeId(id);
    }

    for (final entry in deletedByLayer.entries) {
      final mutableLayer = _ctx.txnEnsureMutableLayer(entry.key);
      final layerDeletedIds = entry.value;
      mutableLayer.nodes.retainWhere(
        (node) => !layerDeletedIds.contains(node.id),
      );
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

  @override
  List<NodeId> writeClearSceneKeepBackground() {
    final scene = _ctx.txnEnsureMutableScene();
    canonicalizeBackgroundLayerInvariants(
      scene.layers,
      onMultipleBackgroundError: (count) {
        throw StateError(
          'clearScene requires at most one background layer; found $count.',
        );
      },
    );

    final layers = scene.layers;
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

  @override
  void writeCameraOffset(Offset offset) {
    _txnRequireFiniteOffset(offset, name: 'offset');
    if (_ctx.workingScene.camera.offset == offset) return;
    final scene = _ctx.txnEnsureMutableScene();
    scene.camera.offset = offset;
    _ctx.changeSet.txnMarkVisualChanged();
  }

  @override
  void writeGridEnable(bool enabled) {
    if (_ctx.workingScene.background.grid.isEnabled == enabled) {
      return;
    }
    final scene = _ctx.txnEnsureMutableScene();
    scene.background.grid.isEnabled = enabled;
    _ctx.changeSet.txnMarkGridChanged();
  }

  @override
  void writeGridCellSize(double cellSize) {
    _txnRequireFinitePositive(cellSize, name: 'cellSize');
    if (_ctx.workingScene.background.grid.cellSize == cellSize) {
      return;
    }
    final scene = _ctx.txnEnsureMutableScene();
    scene.background.grid.cellSize = cellSize;
    _ctx.changeSet.txnMarkGridChanged();
  }

  @override
  void writeBackgroundColor(Color color) {
    if (_ctx.workingScene.background.color == color) {
      return;
    }
    final scene = _ctx.txnEnsureMutableScene();
    scene.background.color = color;
    _ctx.changeSet.txnMarkVisualChanged();
  }

  @override
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

  @override
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

  bool _txnPatchTouchesSelectionPolicy(NodePatch patch) {
    final common = patch.common;
    return !common.isVisible.isAbsent || !common.isSelectable.isAbsent;
  }

  void _txnRequireFiniteOffset(Offset value, {required String name}) {
    if (value.dx.isFinite && value.dy.isFinite) return;
    throw ArgumentError.value(value, name, 'Offset must be finite.');
  }

  void _txnRequireFiniteTransform(Transform2D value, {required String name}) {
    if (value.isFinite) return;
    throw ArgumentError.value(
      value,
      name,
      'Transform2D fields must be finite.',
    );
  }

  void _txnRequireFinitePositive(double value, {required String name}) {
    if (value.isFinite && value > 0) return;
    throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
  }
}
