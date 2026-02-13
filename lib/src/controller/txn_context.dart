import 'package:flutter/foundation.dart';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../model/document.dart';
import '../model/document_clone.dart';
import 'change_set.dart';

class TxnContext {
  TxnContext({
    required Scene baseScene,
    required this.workingSelection,
    required Set<NodeId> baseAllNodeIds,
    required this.nodeIdSeed,
    ChangeSet? changeSet,
  }) : _baseScene = baseScene,
       _baseAllNodeIds = baseAllNodeIds,
       changeSet = changeSet ?? ChangeSet();

  final Scene _baseScene;
  Set<NodeId> _baseAllNodeIds;
  final Set<NodeId> _addedNodeIds = <NodeId>{};
  final Set<NodeId> _removedNodeIds = <NodeId>{};
  Set<NodeId>? _materializedAllNodeIds;
  Scene? _mutableScene;
  final Set<int> _clonedLayerIndexes = <int>{};
  final Set<NodeId> _clonedNodeIds = <NodeId>{};
  bool _mutableSceneOwnedByTxn = false;

  Scene get workingScene => _mutableScene ?? _baseScene;
  Scene txnSceneForCommit() => _mutableScene ?? _baseScene;

  Set<NodeId> workingSelection;
  int nodeIdSeed;
  final ChangeSet changeSet;
  int debugSceneShallowClones = 0;
  int debugLayerShallowClones = 0;
  int debugNodeClones = 0;
  int debugNodeIdSetMaterializations = 0;

  Scene txnEnsureMutableScene() {
    final existing = _mutableScene;
    if (existing != null) return existing;
    final cloned = txnCloneSceneShallow(_baseScene);
    _mutableScene = cloned;
    _mutableSceneOwnedByTxn = false;
    _clonedLayerIndexes.clear();
    _clonedNodeIds.clear();
    debugSceneShallowClones = debugSceneShallowClones + 1;
    return cloned;
  }

  Layer txnEnsureMutableLayer(int layerIndex) {
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
    if (!_txnIsSharedLayerWithBase(current)) {
      return current;
    }

    final cloned = txnCloneLayerShallow(current);
    scene.layers[layerIndex] = cloned;
    _clonedLayerIndexes.add(layerIndex);
    debugLayerShallowClones = debugLayerShallowClones + 1;
    return cloned;
  }

  ({SceneNode node, int layerIndex, int nodeIndex}) txnResolveMutableNode(
    NodeId id,
  ) {
    final foundInWorking = txnFindNodeById(workingScene, id);
    if (foundInWorking == null) {
      throw StateError('Node not found: $id');
    }

    if (_mutableSceneOwnedByTxn) {
      return foundInWorking;
    }

    txnEnsureMutableLayer(foundInWorking.layerIndex);
    final foundAfterLayerClone = txnFindNodeById(workingScene, id);
    if (foundAfterLayerClone == null) {
      throw StateError('Node not found after layer clone: $id');
    }

    if (_clonedNodeIds.contains(id)) {
      return foundAfterLayerClone;
    }
    if (!_txnIsSharedNodeWithBase(foundAfterLayerClone.node)) {
      return foundAfterLayerClone;
    }

    final clonedNode = txnCloneNode(foundAfterLayerClone.node);
    workingScene
            .layers[foundAfterLayerClone.layerIndex]
            .nodes[foundAfterLayerClone.nodeIndex] =
        clonedNode;
    _clonedNodeIds.add(id);
    debugNodeClones = debugNodeClones + 1;
    return (
      node: clonedNode,
      layerIndex: foundAfterLayerClone.layerIndex,
      nodeIndex: foundAfterLayerClone.nodeIndex,
    );
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
    while (true) {
      final candidate = 'node-$nodeIdSeed';
      nodeIdSeed = nodeIdSeed + 1;
      if (!txnHasNodeId(candidate)) {
        txnRememberNodeId(candidate);
        return candidate;
      }
    }
  }

  void txnAdoptScene(Scene scene) {
    _mutableScene = scene;
    _mutableSceneOwnedByTxn = true;
    _clonedLayerIndexes.clear();
    _clonedNodeIds.clear();
    _baseAllNodeIds = txnCollectNodeIds(scene);
    _addedNodeIds.clear();
    _removedNodeIds.clear();
    _materializedAllNodeIds = _baseAllNodeIds;
    nodeIdSeed = txnInitialNodeIdSeed(scene);
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

  bool _txnIsSharedLayerWithBase(Layer layer) {
    for (final baseLayer in _baseScene.layers) {
      if (identical(baseLayer, layer)) {
        return true;
      }
    }
    return false;
  }

  bool _txnIsSharedNodeWithBase(SceneNode node) {
    for (final baseLayer in _baseScene.layers) {
      for (final baseNode in baseLayer.nodes) {
        if (identical(baseNode, node)) {
          return true;
        }
      }
    }
    return false;
  }
}
