import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../contract/ids.dart' show LayerId;
import '../core/id_generator.dart';
import '../core/nodes.dart';
import '../core/revision_policy.dart';
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
    int? nodeIdSeed,
    int? layerIdSeed,
    IdGeneratorState? idGeneratorState,
    RevisionAllocatorState? revisionState,
    int nextInstanceRevision = 1,
    ChangeSet? changeSet,
  }) : _baseScene = baseScene,
       workingSelection = HashSet<NodeId>.of(workingSelection),
       _baseAllNodeIds = baseAllNodeIds,
       _baseNodeLocator = baseNodeLocator ?? txnBuildNodeLocator(baseScene),
       idGeneratorState =
           idGeneratorState?.copy() ??
           createIdGeneratorStateForTesting(
             nextNodeCounter: _normalizeLegacySeed(nodeIdSeed),
             nextLayerCounter: _normalizeLegacySeed(layerIdSeed),
           ),
       revisionState =
           revisionState?.copy() ??
           createInitialRevisionAllocatorState(
             nextInstanceRevision: nextInstanceRevision,
           ),
       changeSet = changeSet ?? ChangeSet();

  final Scene _baseScene;
  Set<NodeId> _baseAllNodeIds;
  final Set<NodeId> _addedNodeIds = <NodeId>{};
  final Set<NodeId> _removedNodeIds = <NodeId>{};
  Set<NodeId>? _materializedAllNodeIds;
  Map<NodeId, NodeLocatorEntry> _baseNodeLocator;
  Map<LayerId, int>? _baseLayerIndexById;
  Map<NodeId, NodeLocatorEntry>? _materializedNodeLocator;
  Map<LayerId, int>? _materializedLayerIndexById;
  Scene? _mutableScene;
  final Set<LayerId> _clonedLayerIds = <LayerId>{};
  bool _backgroundLayerCloned = false;
  final Set<NodeId> _clonedNodeIds = <NodeId>{};
  bool _mutableSceneOwnedByTxn = false;
  bool _isActive = true;

  Scene get workingScene => _mutableScene ?? _baseScene;
  Scene txnSceneForCommit() => _mutableScene ?? _baseScene;

  final Set<NodeId> workingSelection;
  IdGeneratorState idGeneratorState;
  RevisionAllocatorState revisionState;
  final ChangeSet changeSet;
  int debugSceneShallowClones = 0;
  int debugLayerShallowClones = 0;
  int debugNodeClones = 0;
  int debugNodeIdSetMaterializations = 0;
  int debugNodeLocatorMaterializations = 0;
  int debugLayerIdIndexMaterializations = 0;

  int get nodeIdSeed => idGeneratorState.nextNodeCounter;
  set nodeIdSeed(int value) {
    idGeneratorState.nextNodeCounter = value;
  }

  int get layerIdSeed => idGeneratorState.nextLayerCounter;
  set layerIdSeed(int value) {
    idGeneratorState.nextLayerCounter = value;
  }

  int get nextInstanceRevision => revisionState.nextInstanceRevision;
  set nextInstanceRevision(int value) {
    revisionState.nextInstanceRevision = requireRevisionCounter(
      value,
      name: 'nextInstanceRevision',
    );
  }

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
    _clonedLayerIds.clear();
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
    final current = scene.layers[layerIndex];
    if (_clonedLayerIds.contains(current.id)) {
      return scene.layers[layerIndex];
    }
    final baseLayer = _txnBaseLayerById(current.id);
    if (baseLayer == null || !identical(current, baseLayer)) {
      _clonedLayerIds.add(current.id);
      return current;
    }

    final cloned = txnCloneContentLayerShallow(current);
    scene.layers[layerIndex] = cloned;
    _clonedLayerIds.add(cloned.id);
    debugLayerShallowClones = debugLayerShallowClones + 1;
    return cloned;
  }

  bool txnEnsureContentLayer(LayerId layerId, {int? index}) {
    txnEnsureActive();
    if (txnHasLayerId(layerId)) {
      return false;
    }

    final scene = txnEnsureMutableScene();
    final targetIndex = index ?? scene.layers.length;
    if (targetIndex < 0 || targetIndex > scene.layers.length) {
      throw RangeError.range(targetIndex, 0, scene.layers.length, 'index');
    }

    scene.layers.insert(targetIndex, ContentLayer(id: layerId));
    if (targetIndex < scene.layers.length - 1) {
      txnShiftNodeLocatorLayersFrom(
        nodeLocator: txnEnsureMutableNodeLocator(),
        startLayerIndex: targetIndex,
      );
    }
    _txnInvalidateLayerIdIndex();
    return true;
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
    final prepared = _txnPrepareMutableNodeSlot(id);
    return _txnCloneResolvedNodeIfNeeded(prepared);
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
    final candidate = generateNextNodeId(
      idGeneratorState,
      containsNodeId: txnHasNodeId,
    );
    txnRememberNodeId(candidate);
    return candidate;
  }

  bool txnHasLayerId(LayerId layerId) {
    return txnFindContentLayerIndexById(layerId) != null;
  }

  int? txnFindContentLayerIndexById(LayerId layerId) {
    txnEnsureActive();
    final scene = workingScene;
    final indexById =
        _materializedLayerIndexById ??
        _txnMaterializeLayerIdIndexFromWorkingScene();
    if (!indexById.containsKey(layerId)) {
      return null;
    }
    final cachedIndex = _txnResolveLayerIndexFromMap(
      indexById: indexById,
      scene: scene,
      layerId: layerId,
    );
    if (cachedIndex != null) {
      return cachedIndex;
    }
    return _txnResolveLayerIndexByRebuild(scene: scene, layerId: layerId);
  }

  int txnResolveInsertLayerIndex({LayerId? layerId}) {
    txnEnsureActive();
    if (layerId != null) {
      final index = txnFindContentLayerIndexById(layerId);
      if (index == null) {
        throw ArgumentError.value(
          layerId,
          'layerId',
          'Unknown content layer id.',
        );
      }
      return index;
    }

    final scene = txnEnsureMutableScene();
    if (scene.layers.isEmpty) {
      final generatedId = txnNextLayerId();
      scene.layers.add(ContentLayer(id: generatedId));
      _txnInvalidateLayerIdIndex();
      return 0;
    }
    return scene.layers.length - 1;
  }

  LayerId txnNextLayerId() {
    txnEnsureActive();
    return generateNextLayerId(
      idGeneratorState,
      containsLayerId: txnHasLayerId,
    );
  }

  int txnNextInstanceRevision() {
    txnEnsureActive();
    return allocateNextInstanceRevision(revisionState);
  }

  void txnAdoptScene(Scene scene) {
    txnEnsureActive();
    _mutableScene = scene;
    _mutableSceneOwnedByTxn = true;
    _clonedLayerIds.clear();
    _backgroundLayerCloned = false;
    _clonedNodeIds.clear();
    _baseAllNodeIds = txnCollectNodeIds(scene);
    _baseNodeLocator = txnBuildNodeLocator(scene);
    _addedNodeIds.clear();
    _removedNodeIds.clear();
    _materializedAllNodeIds = _baseAllNodeIds;
    _materializedNodeLocator = _baseNodeLocator;
    _materializedLayerIndexById = null;
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

  Map<LayerId, int> _txnMaterializeLayerIdIndexFromWorkingScene({
    bool forceRebuild = false,
  }) {
    final cached = _materializedLayerIndexById;
    if (!forceRebuild && cached != null) {
      return cached;
    }
    final scene = workingScene;
    final indexById = <LayerId, int>{
      for (var index = 0; index < scene.layers.length; index++)
        scene.layers[index].id: index,
    };
    _materializedLayerIndexById = indexById;
    debugLayerIdIndexMaterializations = debugLayerIdIndexMaterializations + 1;
    return indexById;
  }

  int? _txnResolveLayerIndexByRebuild({
    required Scene scene,
    required LayerId layerId,
  }) {
    return _txnResolveLayerIndexFromMap(
      indexById: _txnMaterializeLayerIdIndexFromWorkingScene(
        forceRebuild: true,
      ),
      scene: scene,
      layerId: layerId,
    );
  }

  int? _txnResolveLayerIndexFromMap({
    required Map<LayerId, int> indexById,
    required Scene scene,
    required LayerId layerId,
  }) {
    final index = indexById[layerId];
    if (index == null) {
      return null;
    }
    if (index < 0 || index >= scene.layers.length) {
      return null;
    }
    return scene.layers[index].id == layerId ? index : null;
  }

  void _txnInvalidateLayerIdIndex() {
    _materializedLayerIndexById = null;
  }

  ContentLayer? _txnBaseLayerById(LayerId id) {
    final baseIndexById = _baseLayerIndexById ??= <LayerId, int>{
      for (var index = 0; index < _baseScene.layers.length; index++)
        _baseScene.layers[index].id: index,
    };
    final index = baseIndexById[id];
    if (index == null || index < 0 || index >= _baseScene.layers.length) {
      return null;
    }
    final layer = _baseScene.layers[index];
    if (layer.id != id) {
      return null;
    }
    return layer;
  }

  SceneNode? _txnBaseNodeById(NodeId id) {
    return txnFindNodeByLocator(
      scene: _baseScene,
      nodeLocator: _baseNodeLocator,
      nodeId: id,
    )?.node;
  }

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

  ({SceneNode node, int layerIndex, int nodeIndex}) _txnPrepareMutableNodeSlot(
    NodeId id,
  ) {
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

    final prepared = txnFindNodeById(id);
    if (prepared == null) {
      throw StateError('Node not found after layer clone: $id');
    }
    return prepared;
  }

  ({SceneNode node, int layerIndex, int nodeIndex})
  _txnCloneResolvedNodeIfNeeded(
    ({SceneNode node, int layerIndex, int nodeIndex}) resolved,
  ) {
    final nodeId = resolved.node.id;
    if (_clonedNodeIds.contains(nodeId)) {
      return resolved;
    }
    final baseNode = _txnBaseNodeById(nodeId);
    if (baseNode == null || !identical(resolved.node, baseNode)) {
      return resolved;
    }

    final clonedNode = txnCloneNode(resolved.node);
    if (resolved.layerIndex == -1) {
      final backgroundLayer = workingScene.backgroundLayer;
      if (backgroundLayer == null) {
        throw StateError(
          'Background layer missing after mutable clone: ${resolved.node.id}',
        );
      }
      backgroundLayer.nodes[resolved.nodeIndex] = clonedNode;
    } else {
      workingScene.layers[resolved.layerIndex].nodes[resolved.nodeIndex] =
          clonedNode;
    }
    _clonedNodeIds.add(nodeId);
    debugNodeClones = debugNodeClones + 1;
    return (
      node: clonedNode,
      layerIndex: resolved.layerIndex,
      nodeIndex: resolved.nodeIndex,
    );
  }
}

int _normalizeLegacySeed(int? value) {
  if (value == null || value < 1) {
    return 1;
  }
  return value;
}
