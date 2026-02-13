import '../core/nodes.dart';
import '../core/scene.dart';
import '../model/document.dart';
import '../model/document_clone.dart';
import 'change_set.dart';

class TxnContext {
  TxnContext({
    required Scene baseScene,
    required this.workingSelection,
    required this.workingNodeIds,
    required this.nodeIdSeed,
    ChangeSet? changeSet,
  }) : _baseScene = baseScene,
       changeSet = changeSet ?? ChangeSet();

  final Scene _baseScene;
  Scene? _mutableScene;
  final Set<int> _clonedLayerIndexes = <int>{};
  final Set<NodeId> _clonedNodeIds = <NodeId>{};
  bool _mutableSceneOwnedByTxn = false;

  Scene get workingScene => _mutableScene ?? _baseScene;
  Scene txnSceneForCommit() => _mutableScene ?? _baseScene;

  Set<NodeId> workingSelection;
  final Set<NodeId> workingNodeIds;
  int nodeIdSeed;
  final ChangeSet changeSet;
  int debugSceneShallowClones = 0;
  int debugLayerShallowClones = 0;
  int debugNodeClones = 0;

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

  bool txnHasNodeId(NodeId nodeId) => workingNodeIds.contains(nodeId);

  void txnRememberNodeId(NodeId nodeId) {
    workingNodeIds.add(nodeId);
  }

  void txnForgetNodeId(NodeId nodeId) {
    workingNodeIds.remove(nodeId);
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
    workingNodeIds
      ..clear()
      ..addAll(txnCollectNodeIds(scene));
    nodeIdSeed = txnInitialNodeIdSeed(scene);
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
