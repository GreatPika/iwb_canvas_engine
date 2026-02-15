import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../model/document.dart';
import '../model/document_clone.dart';
import 'change_set.dart';

class TxnContext {
  TxnContext({
    required Scene baseScene,
    required Set<NodeId> workingSelection,
    required Set<NodeId> baseAllNodeIds,
    Map<NodeId, NodeLocatorEntry>? baseNodeLocator,
    required this.nodeIdSeed,
    required this.nextInstanceRevision,
    ChangeSet? changeSet,
  }) : _baseScene = baseScene,
       workingSelection = HashSet<NodeId>.of(workingSelection),
       _baseAllNodeIds = baseAllNodeIds,
       _baseNodeLocator = baseNodeLocator ?? txnBuildNodeLocator(baseScene),
       changeSet = changeSet ?? ChangeSet();

  final Scene _baseScene;
  Set<NodeId> _baseAllNodeIds;
  final Set<NodeId> _addedNodeIds = <NodeId>{};
  final Set<NodeId> _removedNodeIds = <NodeId>{};
  Set<NodeId>? _materializedAllNodeIds;
  Map<NodeId, NodeLocatorEntry> _baseNodeLocator;
  Map<NodeId, NodeLocatorEntry>? _materializedNodeLocator;
  Scene? _mutableScene;
  final Set<int> _clonedLayerIndexes = <int>{};
  bool _backgroundLayerCloned = false;
  final Set<NodeId> _clonedNodeIds = <NodeId>{};
  bool _mutableSceneOwnedByTxn = false;
  bool _isActive = true;

  Scene get workingScene => _mutableScene ?? _baseScene;
  Scene txnSceneForCommit() => _mutableScene ?? _baseScene;

  final Set<NodeId> workingSelection;
  int nodeIdSeed;
  int nextInstanceRevision;
  final ChangeSet changeSet;
  int debugSceneShallowClones = 0;
  int debugLayerShallowClones = 0;
  int debugNodeClones = 0;
  int debugNodeIdSetMaterializations = 0;
  int debugNodeLocatorMaterializations = 0;

  void txnClose() {
    _isActive = false;
  }

  void txnEnsureActive() {
    if (_isActive) {
      return;
    }
    throw StateError('Transaction is closed.');
  }

  Scene txnEnsureMutableScene() {
    txnEnsureActive();
    final existing = _mutableScene;
    if (existing != null) return existing;
    final cloned = txnCloneSceneShallow(_baseScene);
    _mutableScene = cloned;
    _mutableSceneOwnedByTxn = false;
    _clonedLayerIndexes.clear();
    _backgroundLayerCloned = false;
    _clonedNodeIds.clear();
    debugSceneShallowClones = debugSceneShallowClones + 1;
    return cloned;
  }

  ContentLayer txnEnsureMutableLayer(int layerIndex) {
    txnEnsureActive();
    final scene = txnEnsureMutableScene();
    if (layerIndex < 0 || layerIndex >= scene.layers.length) {
      throw RangeError.range(
        layerIndex,
        0,
        scene.layers.length - 1,
        'layerIndex',
      );
    }
    if (_mutableSceneOwnedByTxn) {
      return scene.layers[layerIndex];
    }
    if (_clonedLayerIndexes.contains(layerIndex)) {
      return scene.layers[layerIndex];
    }

    final current = scene.layers[layerIndex];
    final baseLayer = _txnBaseLayerAt(layerIndex);
    if (!identical(current, baseLayer)) {
      _clonedLayerIndexes.add(layerIndex);
      return current;
    }

    final cloned = txnCloneContentLayerShallow(current);
    scene.layers[layerIndex] = cloned;
    _clonedLayerIndexes.add(layerIndex);
    debugLayerShallowClones = debugLayerShallowClones + 1;
    return cloned;
  }

  BackgroundLayer txnEnsureMutableBackgroundLayer() {
    txnEnsureActive();
    final scene = txnEnsureMutableScene();
    final current = scene.backgroundLayer;
    if (current == null) {
      final created = BackgroundLayer();
      scene.backgroundLayer = created;
      _backgroundLayerCloned = true;
      debugLayerShallowClones = debugLayerShallowClones + 1;
      return created;
    }
    if (_mutableSceneOwnedByTxn || _backgroundLayerCloned) {
      return current;
    }

    final baseLayer = _baseScene.backgroundLayer;
    if (!identical(current, baseLayer)) {
      _backgroundLayerCloned = true;
      return current;
    }

    final cloned = txnCloneBackgroundLayerShallow(current);
    scene.backgroundLayer = cloned;
    _backgroundLayerCloned = true;
    debugLayerShallowClones = debugLayerShallowClones + 1;
    return cloned;
  }

  ({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeById(
    NodeId id,
  ) {
    return txnFindNodeByLocator(
      scene: workingScene,
      nodeLocator: _workingNodeLocator,
      nodeId: id,
    );
  }

  ({SceneNode node, int layerIndex, int nodeIndex}) txnResolveMutableNode(
    NodeId id,
  ) {
    txnEnsureActive();
    final foundInWorking = txnFindNodeById(id);
    if (foundInWorking == null) {
      throw StateError('Node not found: $id');
    }

    if (_mutableSceneOwnedByTxn) {
      return foundInWorking;
    }

    if (foundInWorking.layerIndex == -1) {
      txnEnsureMutableBackgroundLayer();
    } else {
      txnEnsureMutableLayer(foundInWorking.layerIndex);
    }
    final foundAfterLayerClone = txnFindNodeById(id);
    if (foundAfterLayerClone == null) {
      throw StateError('Node not found after layer clone: $id');
    }

    if (_clonedNodeIds.contains(id)) {
      return foundAfterLayerClone;
    }
    final baseNode = _txnBaseNodeAt(
      layerIndex: foundAfterLayerClone.layerIndex,
      nodeIndex: foundAfterLayerClone.nodeIndex,
    );
    if (!identical(foundAfterLayerClone.node, baseNode)) {
      return foundAfterLayerClone;
    }

    final clonedNode = txnCloneNode(foundAfterLayerClone.node);
    if (foundAfterLayerClone.layerIndex == -1) {
      final backgroundLayer = workingScene.backgroundLayer;
      if (backgroundLayer == null) {
        throw StateError('Background layer missing after mutable clone: $id');
      }
      backgroundLayer.nodes[foundAfterLayerClone.nodeIndex] = clonedNode;
    } else {
      workingScene
              .layers[foundAfterLayerClone.layerIndex]
              .nodes[foundAfterLayerClone.nodeIndex] =
          clonedNode;
    }
    _clonedNodeIds.add(id);
    debugNodeClones = debugNodeClones + 1;
    return (
      node: clonedNode,
      layerIndex: foundAfterLayerClone.layerIndex,
      nodeIndex: foundAfterLayerClone.nodeIndex,
    );
  }

  Map<NodeId, NodeLocatorEntry> txnEnsureMutableNodeLocator() {
    txnEnsureActive();
    return _txnMaterializeNodeLocator();
  }

  void txnRebuildNodeLocatorFromWorkingScene() {
    txnEnsureActive();
    final rebuilt = txnBuildNodeLocator(workingScene);
    if (_materializedNodeLocator == null) {
      debugNodeLocatorMaterializations = debugNodeLocatorMaterializations + 1;
    }
    _materializedNodeLocator = rebuilt;
  }

  bool txnHasNodeId(NodeId nodeId) {
    final materialized = _materializedAllNodeIds;
    if (materialized != null) {
      return materialized.contains(nodeId);
    }
    if (_addedNodeIds.contains(nodeId)) {
      return true;
    }
    if (_removedNodeIds.contains(nodeId)) {
      return false;
    }
    return _baseAllNodeIds.contains(nodeId);
  }

  void txnRememberNodeId(NodeId nodeId) {
    txnEnsureActive();
    final materialized = _materializedAllNodeIds;
    if (materialized != null) {
      materialized.add(nodeId);
      return;
    }
    if (_baseAllNodeIds.contains(nodeId)) {
      _removedNodeIds.remove(nodeId);
      return;
    }
    _addedNodeIds.add(nodeId);
  }

  void txnForgetNodeId(NodeId nodeId) {
    txnEnsureActive();
    final materialized = _materializedAllNodeIds;
    if (materialized != null) {
      materialized.remove(nodeId);
      return;
    }
    if (_baseAllNodeIds.contains(nodeId)) {
      _removedNodeIds.add(nodeId);
      return;
    }
    _addedNodeIds.remove(nodeId);
  }

  String txnNextNodeId() {
    txnEnsureActive();
    while (true) {
      final candidate = 'node-$nodeIdSeed';
      nodeIdSeed = nodeIdSeed + 1;
      if (!txnHasNodeId(candidate)) {
        txnRememberNodeId(candidate);
        return candidate;
      }
    }
  }

  int txnNextInstanceRevision() {
    txnEnsureActive();
    final out = nextInstanceRevision;
    nextInstanceRevision = nextInstanceRevision + 1;
    return out;
  }

  void txnAdoptScene(Scene scene) {
    txnEnsureActive();
    final prevNextInstanceRevision = nextInstanceRevision;
    _mutableScene = scene;
    _mutableSceneOwnedByTxn = true;
    _clonedLayerIndexes.clear();
    _backgroundLayerCloned = false;
    _clonedNodeIds.clear();
    _baseAllNodeIds = txnCollectNodeIds(scene);
    _baseNodeLocator = txnBuildNodeLocator(scene);
    _addedNodeIds.clear();
    _removedNodeIds.clear();
    _materializedAllNodeIds = _baseAllNodeIds;
    _materializedNodeLocator = _baseNodeLocator;
    nodeIdSeed = txnInitialNodeIdSeed(scene);
    final adoptedSeed = txnInitialNodeInstanceRevisionSeed(scene);
    nextInstanceRevision = prevNextInstanceRevision >= adoptedSeed
        ? prevNextInstanceRevision
        : adoptedSeed;
  }

  Set<NodeId> txnAllNodeIdsForCommit({required bool structuralChanged}) {
    final materialized = _materializedAllNodeIds;
    if (materialized != null) {
      return materialized;
    }
    if (!structuralChanged &&
        _addedNodeIds.isEmpty &&
        _removedNodeIds.isEmpty) {
      return _baseAllNodeIds;
    }
    return _txnMaterializeAllNodeIds();
  }

  Map<NodeId, NodeLocatorEntry> txnNodeLocatorForCommit({
    required bool structuralChanged,
  }) {
    final materialized = _materializedNodeLocator;
    if (materialized != null) {
      return materialized;
    }
    if (!structuralChanged) {
      return _baseNodeLocator;
    }
    return _txnMaterializeNodeLocator();
  }

  Map<NodeId, NodeLocatorEntry> txnNodeLocatorView() {
    txnEnsureActive();
    return _workingNodeLocator;
  }

  Set<NodeId> _txnMaterializeAllNodeIds() {
    final cached = _materializedAllNodeIds;
    if (cached != null) {
      return cached;
    }
    final materialized = Set<NodeId>.from(_baseAllNodeIds);
    if (_removedNodeIds.isNotEmpty) {
      materialized.removeAll(_removedNodeIds);
    }
    if (_addedNodeIds.isNotEmpty) {
      materialized.addAll(_addedNodeIds);
    }
    _materializedAllNodeIds = materialized;
    debugNodeIdSetMaterializations = debugNodeIdSetMaterializations + 1;
    return materialized;
  }

  @visibleForTesting
  Set<NodeId> debugNodeIdsView({required bool structuralChanged}) {
    return txnAllNodeIdsForCommit(structuralChanged: structuralChanged);
  }

  @visibleForTesting
  Map<NodeId, NodeLocatorEntry> debugNodeLocatorView({
    required bool structuralChanged,
  }) {
    return txnNodeLocatorForCommit(structuralChanged: structuralChanged);
  }

  Map<NodeId, NodeLocatorEntry> get _workingNodeLocator =>
      _materializedNodeLocator ?? _baseNodeLocator;

  Map<NodeId, NodeLocatorEntry> _txnMaterializeNodeLocator() {
    final cached = _materializedNodeLocator;
    if (cached != null) {
      return cached;
    }
    final materialized = Map<NodeId, NodeLocatorEntry>.from(_baseNodeLocator);
    _materializedNodeLocator = materialized;
    debugNodeLocatorMaterializations = debugNodeLocatorMaterializations + 1;
    return materialized;
  }

  ContentLayer? _txnBaseLayerAt(int layerIndex) {
    if (layerIndex < 0 || layerIndex >= _baseScene.layers.length) {
      return null;
    }
    return _baseScene.layers[layerIndex];
  }

  SceneNode? _txnBaseNodeAt({required int layerIndex, required int nodeIndex}) {
    if (layerIndex == -1) {
      final backgroundLayer = _baseScene.backgroundLayer;
      if (backgroundLayer == null) {
        return null;
      }
      if (nodeIndex < 0 || nodeIndex >= backgroundLayer.nodes.length) {
        return null;
      }
      return backgroundLayer.nodes[nodeIndex];
    }
    final layer = _txnBaseLayerAt(layerIndex);
    if (layer == null) {
      return null;
    }
    if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
      return null;
    }
    return layer.nodes[nodeIndex];
  }
}
