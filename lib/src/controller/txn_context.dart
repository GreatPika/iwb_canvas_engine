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
  }) : workingSelection = HashSet<NodeId>.of(workingSelection),
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
       changeSet = changeSet ?? ChangeSet(),
       _debugStats = _TxnDebugStats(),
       _derivedState = _TxnDerivedState(
         baseAllNodeIds: baseAllNodeIds,
         baseNodeLocator: baseNodeLocator ?? txnBuildNodeLocator(baseScene),
       ),
       _workspace = _TxnWorkspace(baseScene: baseScene);

  final Set<NodeId> workingSelection;
  IdGeneratorState idGeneratorState;
  RevisionAllocatorState revisionState;
  final ChangeSet changeSet;
  final _TxnDebugStats _debugStats;
  final _TxnDerivedState _derivedState;
  final _TxnWorkspace _workspace;
  bool _isActive = true;

  Scene get workingScene => _workspace.workingScene;
  Scene txnSceneForCommit() => _workspace.sceneForCommit();

  int get debugSceneShallowClones => _debugStats.sceneShallowClones;
  int get debugLayerShallowClones => _debugStats.layerShallowClones;
  int get debugNodeClones => _debugStats.nodeClones;
  int get debugNodeIdSetMaterializations =>
      _debugStats.nodeIdSetMaterializations;
  int get debugNodeLocatorMaterializations =>
      _debugStats.nodeLocatorMaterializations;
  int get debugLayerIdIndexMaterializations =>
      _debugStats.layerIdIndexMaterializations;

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
    return _workspace.ensureMutableScene(_debugStats);
  }

  ContentLayer txnEnsureMutableLayer(int layerIndex) {
    return _workspace.ensureMutableLayer(
      ctx: this,
      derivedState: _derivedState,
      layerIndex: layerIndex,
    );
  }

  bool txnEnsureContentLayer(LayerId layerId, {int? index}) {
    return _workspace.ensureContentLayer(
      ctx: this,
      derivedState: _derivedState,
      layerId: layerId,
      index: index,
    );
  }

  BackgroundLayer txnEnsureMutableBackgroundLayer() {
    return _workspace.ensureMutableBackgroundLayer(
      ctx: this,
      debugStats: _debugStats,
    );
  }

  ({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeById(
    NodeId id,
  ) {
    return txnFindNodeByLocator(
      scene: workingScene,
      nodeLocator: _derivedState.workingNodeLocator,
      nodeId: id,
    );
  }

  ({SceneNode node, int layerIndex, int nodeIndex}) txnResolveMutableNode(
    NodeId id,
  ) {
    return _workspace.resolveMutableNode(
      ctx: this,
      derivedState: _derivedState,
      id: id,
      debugStats: _debugStats,
    );
  }

  Map<NodeId, NodeLocatorEntry> txnEnsureMutableNodeLocator() {
    txnEnsureActive();
    return _derivedState.ensureMutableNodeLocator(_debugStats);
  }

  void txnRebuildNodeLocatorFromWorkingScene() {
    txnEnsureActive();
    _derivedState.rebuildNodeLocatorFromWorkingScene(
      scene: workingScene,
      debugStats: _debugStats,
    );
  }

  bool txnHasNodeId(NodeId nodeId) {
    return _derivedState.hasNodeId(nodeId);
  }

  void txnRememberNodeId(NodeId nodeId) {
    txnEnsureActive();
    _derivedState.rememberNodeId(nodeId);
  }

  void txnForgetNodeId(NodeId nodeId) {
    txnEnsureActive();
    _derivedState.forgetNodeId(nodeId);
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
    return _derivedState.hasLayerId(ctx: this, layerId: layerId);
  }

  int? txnFindContentLayerIndexById(LayerId layerId) {
    return _derivedState.findContentLayerIndexById(ctx: this, layerId: layerId);
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
      _derivedState.invalidateLayerIdIndex();
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
    _workspace.adoptScene(scene);
    _derivedState.adoptScene(scene);
  }

  Set<NodeId> txnAllNodeIdsForCommit({required bool structuralChanged}) {
    return _derivedState.allNodeIdsForCommit(
      structuralChanged: structuralChanged,
      debugStats: _debugStats,
    );
  }

  Map<NodeId, NodeLocatorEntry> txnNodeLocatorForCommit({
    required bool structuralChanged,
  }) {
    return _derivedState.nodeLocatorForCommit(
      structuralChanged: structuralChanged,
      debugStats: _debugStats,
    );
  }

  Map<NodeId, NodeLocatorEntry> txnNodeLocatorView() {
    txnEnsureActive();
    return _derivedState.nodeLocatorView();
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
}

class _TxnWorkspace {
  _TxnWorkspace({required Scene baseScene}) : _baseScene = baseScene;

  final Scene _baseScene;
  Scene? _mutableScene;
  final Set<LayerId> _clonedLayerIds = <LayerId>{};
  bool _backgroundLayerCloned = false;
  final Set<NodeId> _clonedNodeIds = <NodeId>{};
  bool _mutableSceneOwnedByTxn = false;

  Scene get workingScene => _mutableScene ?? _baseScene;
  Scene sceneForCommit() => _mutableScene ?? _baseScene;

  Scene ensureMutableScene(_TxnDebugStats debugStats) {
    final existing = _mutableScene;
    if (existing != null) {
      return existing;
    }
    final cloned = txnCloneSceneShallow(_baseScene);
    _mutableScene = cloned;
    _mutableSceneOwnedByTxn = false;
    _clonedLayerIds.clear();
    _backgroundLayerCloned = false;
    _clonedNodeIds.clear();
    debugStats.sceneShallowClones = debugStats.sceneShallowClones + 1;
    return cloned;
  }

  ContentLayer ensureMutableLayer({
    required TxnContext ctx,
    required _TxnDerivedState derivedState,
    required int layerIndex,
  }) {
    ctx.txnEnsureActive();
    final scene = ensureMutableScene(ctx._debugStats);
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
    final baseLayer = derivedState.baseLayerById(
      baseScene: _baseScene,
      layerId: current.id,
    );
    if (baseLayer == null || !identical(current, baseLayer)) {
      _clonedLayerIds.add(current.id);
      return current;
    }

    final cloned = txnCloneContentLayerShallow(current);
    scene.layers[layerIndex] = cloned;
    _clonedLayerIds.add(cloned.id);
    ctx._debugStats.layerShallowClones = ctx._debugStats.layerShallowClones + 1;
    return cloned;
  }

  bool ensureContentLayer({
    required TxnContext ctx,
    required _TxnDerivedState derivedState,
    required LayerId layerId,
    int? index,
  }) {
    ctx.txnEnsureActive();
    if (derivedState.hasLayerId(ctx: ctx, layerId: layerId)) {
      return false;
    }

    final scene = ensureMutableScene(ctx._debugStats);
    final targetIndex = index ?? scene.layers.length;
    if (targetIndex < 0 || targetIndex > scene.layers.length) {
      throw RangeError.range(targetIndex, 0, scene.layers.length, 'index');
    }

    scene.layers.insert(targetIndex, ContentLayer(id: layerId));
    if (targetIndex < scene.layers.length - 1) {
      txnShiftNodeLocatorLayersFrom(
        nodeLocator: derivedState.ensureMutableNodeLocator(ctx._debugStats),
        startLayerIndex: targetIndex,
      );
    }
    derivedState.invalidateLayerIdIndex();
    return true;
  }

  BackgroundLayer ensureMutableBackgroundLayer({
    required TxnContext ctx,
    required _TxnDebugStats debugStats,
  }) {
    ctx.txnEnsureActive();
    final scene = ensureMutableScene(debugStats);
    final current = scene.backgroundLayer;
    if (current == null) {
      final created = BackgroundLayer();
      scene.backgroundLayer = created;
      _backgroundLayerCloned = true;
      debugStats.layerShallowClones = debugStats.layerShallowClones + 1;
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
    debugStats.layerShallowClones = debugStats.layerShallowClones + 1;
    return cloned;
  }

  ({SceneNode node, int layerIndex, int nodeIndex}) resolveMutableNode({
    required TxnContext ctx,
    required _TxnDerivedState derivedState,
    required NodeId id,
    required _TxnDebugStats debugStats,
  }) {
    ctx.txnEnsureActive();
    final prepared = _prepareMutableNodeSlot(ctx: ctx, id: id);
    return _cloneResolvedNodeIfNeeded(
      derivedState: derivedState,
      resolved: prepared,
      debugStats: debugStats,
    );
  }

  void adoptScene(Scene scene) {
    _mutableScene = scene;
    _mutableSceneOwnedByTxn = true;
    _clonedLayerIds.clear();
    _backgroundLayerCloned = false;
    _clonedNodeIds.clear();
  }

  ({SceneNode node, int layerIndex, int nodeIndex}) _prepareMutableNodeSlot({
    required TxnContext ctx,
    required NodeId id,
  }) {
    final foundInWorking = ctx.txnFindNodeById(id);
    if (foundInWorking == null) {
      throw StateError('Node not found: $id');
    }
    if (_mutableSceneOwnedByTxn) {
      return foundInWorking;
    }

    if (foundInWorking.layerIndex == -1) {
      ctx.txnEnsureMutableBackgroundLayer();
    } else {
      ctx.txnEnsureMutableLayer(foundInWorking.layerIndex);
    }

    final prepared = ctx.txnFindNodeById(id);
    if (prepared == null) {
      throw StateError('Node not found after layer clone: $id');
    }
    return prepared;
  }

  ({SceneNode node, int layerIndex, int nodeIndex}) _cloneResolvedNodeIfNeeded({
    required _TxnDerivedState derivedState,
    required ({SceneNode node, int layerIndex, int nodeIndex}) resolved,
    required _TxnDebugStats debugStats,
  }) {
    final nodeId = resolved.node.id;
    if (_clonedNodeIds.contains(nodeId)) {
      return resolved;
    }
    final baseNode = derivedState.baseNodeById(
      baseScene: _baseScene,
      nodeId: nodeId,
    );
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
    debugStats.nodeClones = debugStats.nodeClones + 1;
    return (
      node: clonedNode,
      layerIndex: resolved.layerIndex,
      nodeIndex: resolved.nodeIndex,
    );
  }
}

class _TxnDerivedState {
  _TxnDerivedState({
    required Set<NodeId> baseAllNodeIds,
    required Map<NodeId, NodeLocatorEntry> baseNodeLocator,
  }) : _baseAllNodeIds = baseAllNodeIds,
       _baseNodeLocator = baseNodeLocator;

  Set<NodeId> _baseAllNodeIds;
  final Set<NodeId> _addedNodeIds = <NodeId>{};
  final Set<NodeId> _removedNodeIds = <NodeId>{};
  Set<NodeId>? _materializedAllNodeIds;
  Map<NodeId, NodeLocatorEntry> _baseNodeLocator;
  Map<LayerId, int>? _baseLayerIndexById;
  Map<NodeId, NodeLocatorEntry>? _materializedNodeLocator;
  Map<LayerId, int>? _materializedLayerIndexById;

  Map<NodeId, NodeLocatorEntry> get workingNodeLocator =>
      _materializedNodeLocator ?? _baseNodeLocator;

  Map<NodeId, NodeLocatorEntry> ensureMutableNodeLocator(
    _TxnDebugStats debugStats,
  ) {
    final cached = _materializedNodeLocator;
    if (cached != null) {
      return cached;
    }
    final materialized = Map<NodeId, NodeLocatorEntry>.from(_baseNodeLocator);
    _materializedNodeLocator = materialized;
    debugStats.nodeLocatorMaterializations =
        debugStats.nodeLocatorMaterializations + 1;
    return materialized;
  }

  void rebuildNodeLocatorFromWorkingScene({
    required Scene scene,
    required _TxnDebugStats debugStats,
  }) {
    final rebuilt = txnBuildNodeLocator(scene);
    if (_materializedNodeLocator == null) {
      debugStats.nodeLocatorMaterializations =
          debugStats.nodeLocatorMaterializations + 1;
    }
    _materializedNodeLocator = rebuilt;
  }

  bool hasNodeId(NodeId nodeId) {
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

  void rememberNodeId(NodeId nodeId) {
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

  void forgetNodeId(NodeId nodeId) {
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

  bool hasLayerId({required TxnContext ctx, required LayerId layerId}) {
    return findContentLayerIndexById(ctx: ctx, layerId: layerId) != null;
  }

  int? findContentLayerIndexById({
    required TxnContext ctx,
    required LayerId layerId,
  }) {
    ctx.txnEnsureActive();
    final scene = ctx.workingScene;
    final indexById =
        _materializedLayerIndexById ??
        _materializeLayerIdIndexFromScene(
          scene: scene,
          debugStats: ctx._debugStats,
        );
    if (!indexById.containsKey(layerId)) {
      return null;
    }
    final cachedIndex = _resolveLayerIndexFromMap(
      indexById: indexById,
      scene: scene,
      layerId: layerId,
    );
    if (cachedIndex != null) {
      return cachedIndex;
    }
    return _resolveLayerIndexByRebuild(
      scene: scene,
      layerId: layerId,
      debugStats: ctx._debugStats,
    );
  }

  void invalidateLayerIdIndex() {
    _materializedLayerIndexById = null;
  }

  Set<NodeId> allNodeIdsForCommit({
    required bool structuralChanged,
    required _TxnDebugStats debugStats,
  }) {
    final materialized = _materializedAllNodeIds;
    if (materialized != null) {
      return materialized;
    }
    if (!structuralChanged &&
        _addedNodeIds.isEmpty &&
        _removedNodeIds.isEmpty) {
      return _baseAllNodeIds;
    }
    return _materializeAllNodeIds(debugStats);
  }

  Map<NodeId, NodeLocatorEntry> nodeLocatorForCommit({
    required bool structuralChanged,
    required _TxnDebugStats debugStats,
  }) {
    final materialized = _materializedNodeLocator;
    if (materialized != null) {
      return materialized;
    }
    if (!structuralChanged) {
      return _baseNodeLocator;
    }
    return ensureMutableNodeLocator(debugStats);
  }

  Map<NodeId, NodeLocatorEntry> nodeLocatorView() {
    return workingNodeLocator;
  }

  void adoptScene(Scene scene) {
    _baseAllNodeIds = txnCollectNodeIds(scene);
    _baseNodeLocator = txnBuildNodeLocator(scene);
    _baseLayerIndexById = null;
    _addedNodeIds.clear();
    _removedNodeIds.clear();
    _materializedAllNodeIds = _baseAllNodeIds;
    _materializedNodeLocator = _baseNodeLocator;
    _materializedLayerIndexById = null;
  }

  ContentLayer? baseLayerById({
    required Scene baseScene,
    required LayerId layerId,
  }) {
    final baseIndexById = _baseLayerIndexById ??= <LayerId, int>{
      for (var index = 0; index < baseScene.layers.length; index++)
        baseScene.layers[index].id: index,
    };
    final index = baseIndexById[layerId];
    if (index == null || index < 0 || index >= baseScene.layers.length) {
      return null;
    }
    final layer = baseScene.layers[index];
    if (layer.id != layerId) {
      return null;
    }
    return layer;
  }

  SceneNode? baseNodeById({required Scene baseScene, required NodeId nodeId}) {
    return txnFindNodeByLocator(
      scene: baseScene,
      nodeLocator: _baseNodeLocator,
      nodeId: nodeId,
    )?.node;
  }

  Set<NodeId> _materializeAllNodeIds(_TxnDebugStats debugStats) {
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
    debugStats.nodeIdSetMaterializations =
        debugStats.nodeIdSetMaterializations + 1;
    return materialized;
  }

  Map<LayerId, int> _materializeLayerIdIndexFromScene({
    required Scene scene,
    required _TxnDebugStats debugStats,
    bool forceRebuild = false,
  }) {
    final cached = _materializedLayerIndexById;
    if (!forceRebuild && cached != null) {
      return cached;
    }
    final indexById = <LayerId, int>{
      for (var index = 0; index < scene.layers.length; index++)
        scene.layers[index].id: index,
    };
    _materializedLayerIndexById = indexById;
    debugStats.layerIdIndexMaterializations =
        debugStats.layerIdIndexMaterializations + 1;
    return indexById;
  }

  int? _resolveLayerIndexByRebuild({
    required Scene scene,
    required LayerId layerId,
    required _TxnDebugStats debugStats,
  }) {
    return _resolveLayerIndexFromMap(
      indexById: _materializeLayerIdIndexFromScene(
        scene: scene,
        debugStats: debugStats,
        forceRebuild: true,
      ),
      scene: scene,
      layerId: layerId,
    );
  }

  int? _resolveLayerIndexFromMap({
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
}

class _TxnDebugStats {
  int sceneShallowClones = 0;
  int layerShallowClones = 0;
  int nodeClones = 0;
  int nodeIdSetMaterializations = 0;
  int nodeLocatorMaterializations = 0;
  int layerIdIndexMaterializations = 0;
}

int _normalizeLegacySeed(int? value) {
  if (value == null || value < 1) {
    return 1;
  }
  return value;
}
