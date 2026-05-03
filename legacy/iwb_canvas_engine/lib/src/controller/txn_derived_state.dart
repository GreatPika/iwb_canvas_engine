part of 'txn_context.dart';

class _TxnDerivedState {
  _TxnDerivedState({
    required Set<NodeId> baseAllNodeIds,
    required Map<NodeId, NodeLocatorEntry> baseNodeLocator,
    required Map<LayerId, int> baseLayerIndexById,
  }) : _baseAllNodeIds = baseAllNodeIds,
       _baseNodeLocator = baseNodeLocator,
       _baseLayerIndexById = baseLayerIndexById;

  Set<NodeId> _baseAllNodeIds;
  final Set<NodeId> _addedNodeIds = <NodeId>{};
  final Set<NodeId> _removedNodeIds = <NodeId>{};
  Set<NodeId>? _materializedAllNodeIds;
  Map<NodeId, NodeLocatorEntry> _baseNodeLocator;
  Map<LayerId, int> _baseLayerIndexById;
  Map<NodeId, NodeLocatorEntry>? _materializedNodeLocator;
  Map<LayerId, int>? _materializedLayerIndexById;
}

extension TxnDerivedStateContext on TxnContext {
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

  bool txnHasLayerId(LayerId layerId) {
    return _derivedState.hasLayerId(ctx: this, layerId: layerId);
  }

  int? txnFindContentLayerIndexById(LayerId layerId) {
    return _derivedState.findContentLayerIndexById(ctx: this, layerId: layerId);
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

  Map<LayerId, int> txnLayerIndexByIdView() {
    txnEnsureActive();
    return _derivedState.layerIndexByIdView(
      scene: workingScene,
      debugStats: _debugStats,
    );
  }

  Map<LayerId, int> txnLayerIndexByIdForCommit({
    required bool structuralChanged,
  }) {
    return _derivedState.layerIndexByIdForCommit(
      scene: workingScene,
      structuralChanged: structuralChanged,
      debugStats: _debugStats,
    );
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

extension _TxnDerivedStateNodeSetOps on _TxnDerivedState {
  Map<NodeId, NodeLocatorEntry> get workingNodeLocator =>
      _materializedNodeLocator ?? _baseNodeLocator;

  Map<LayerId, int> workingLayerIndexById({
    required Scene scene,
    required _TxnDebugStats debugStats,
  }) {
    return _materializedLayerIndexById ??
        _materializeLayerIdIndexFromScene(scene: scene, debugStats: debugStats);
  }

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
    _updateNodeIdMembership(nodeId, present: true);
  }

  void forgetNodeId(NodeId nodeId) {
    _updateNodeIdMembership(nodeId, present: false);
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
    _baseLayerIndexById = txnBuildLayerIndexById(scene);
    _addedNodeIds.clear();
    _removedNodeIds.clear();
    _materializedAllNodeIds = _baseAllNodeIds;
    _materializedNodeLocator = _baseNodeLocator;
    _materializedLayerIndexById = _baseLayerIndexById;
  }
}

extension _TxnDerivedStateBaseLookupOps on _TxnDerivedState {
  ContentLayer? baseLayerById({
    required Scene baseScene,
    required LayerId layerId,
  }) {
    final index = _baseLayerIndexById[layerId];
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
      layerIndexById: _baseLayerIndexById,
      nodeId: nodeId,
    )?.node;
  }
}

extension _TxnDerivedStateLayerIndexOps on _TxnDerivedState {
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

  Map<LayerId, int> ensureMutableLayerIndexById({
    required Scene scene,
    required _TxnDebugStats debugStats,
  }) {
    final cached = _materializedLayerIndexById;
    if (cached != null) {
      return cached;
    }
    final materialized = Map<LayerId, int>.from(
      _materializeLayerIdIndexFromScene(scene: scene, debugStats: debugStats),
    );
    _materializedLayerIndexById = materialized;
    return materialized;
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
    final indexById = txnBuildLayerIndexById(scene);
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

  Map<LayerId, int> layerIndexByIdView({
    required Scene scene,
    required _TxnDebugStats debugStats,
  }) {
    return workingLayerIndexById(scene: scene, debugStats: debugStats);
  }

  Map<LayerId, int> layerIndexByIdForCommit({
    required Scene scene,
    required bool structuralChanged,
    required _TxnDebugStats debugStats,
  }) {
    if (!structuralChanged) {
      final materialized = _materializedLayerIndexById;
      if (materialized != null) {
        return materialized;
      }
      return _baseLayerIndexById;
    }
    return _materializeLayerIdIndexFromScene(
      scene: scene,
      debugStats: debugStats,
      forceRebuild: true,
    );
  }

  void _updateNodeIdMembership(NodeId nodeId, {required bool present}) {
    final materialized = _materializedAllNodeIds;
    if (materialized != null) {
      if (present) {
        materialized.add(nodeId);
      } else {
        materialized.remove(nodeId);
      }
      return;
    }

    final isBaseNode = _baseAllNodeIds.contains(nodeId);
    if (isBaseNode) {
      if (present) {
        _removedNodeIds.remove(nodeId);
      } else {
        _removedNodeIds.add(nodeId);
      }
      return;
    }

    if (present) {
      _addedNodeIds.add(nodeId);
    } else {
      _addedNodeIds.remove(nodeId);
    }
  }
}
