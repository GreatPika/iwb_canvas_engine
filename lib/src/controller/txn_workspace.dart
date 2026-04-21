part of 'txn_context.dart';

class _TxnWorkspace {
  _TxnWorkspace({required Scene baseScene}) : _baseScene = baseScene;

  final Scene _baseScene;
  Scene? _mutableScene;
  final Set<LayerId> _clonedLayerIds = <LayerId>{};
  bool _backgroundLayerCloned = false;
  final Set<NodeId> _clonedNodeIds = <NodeId>{};
  bool _mutableSceneOwnedByTxn = false;
}

extension TxnWorkspaceContext on TxnContext {
  Scene txnEnsureMutableScene() {
    txnEnsureActive();
    return _workspace.ensureMutableScene(_debugStats);
  }

  bool txnEnsureContentLayer(LayerId layerId, {int? index}) {
    return _workspace.ensureContentLayer(
      ctx: this,
      derivedState: _derivedState,
      layerId: layerId,
      index: index,
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

  int txnResolveInsertLayerIndex({LayerId? layerId}) {
    txnEnsureActive();
    if (layerId != null) {
      final index = _derivedState.findContentLayerIndexById(
        ctx: this,
        layerId: layerId,
      );
      if (index == null) {
        throw ArgumentError.value(
          layerId,
          'layerId',
          'Unknown content layer id.',
        );
      }
      return index;
    }
    return _workspace.resolveInsertLayerIndex(
      ctx: this,
      derivedState: _derivedState,
    );
  }

  void txnAdoptScene(Scene scene) {
    txnEnsureActive();
    _workspace.adoptScene(scene);
    _derivedState.adoptScene(scene);
  }
}

extension _TxnWorkspaceSceneOps on _TxnWorkspace {
  Scene get workingScene => _mutableScene ?? _baseScene;

  Scene sceneForCommit() => _mutableScene ?? _baseScene;

  int resolveInsertLayerIndex({
    required TxnContext ctx,
    required _TxnDerivedState derivedState,
  }) {
    final scene = ensureMutableScene(ctx._debugStats);
    final previousLayerCount = scene.layers.length;
    final resolvedIndex = txnResolveInsertLayerIndex(
      scene: scene,
      nextLayerId: ctx.txnNextLayerId,
    );
    if (scene.layers.length != previousLayerCount) {
      derivedState.invalidateLayerIdIndex();
    }
    return resolvedIndex;
  }

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
    final targetIndex = txnInsertContentLayerInScene(
      scene: scene,
      layerId: layerId,
      insertIndex: index,
    );
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
}

extension _TxnWorkspaceNodeOps on _TxnWorkspace {
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
    txnReplaceContentLayerInScene(
      scene: scene,
      layerIndex: layerIndex,
      layer: cloned,
    );
    _clonedLayerIds.add(cloned.id);
    ctx._debugStats.layerShallowClones = ctx._debugStats.layerShallowClones + 1;
    return cloned;
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
