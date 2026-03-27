import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/selection_policy.dart';
import 'document_locator.dart' as locator;

SceneNode? txnEraseNodeFromScene({
  required Scene scene,
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
  required NodeId nodeId,
}) {
  final found = locator.txnFindNodeByLocator(
    scene: scene,
    nodeLocator: nodeLocator,
    nodeId: nodeId,
  );
  if (found == null) {
    return null;
  }
  final removed = found.node;
  final removedNodeIds = txnErasePreparedNodesFromScene(
    scene: scene,
    nodeLocator: nodeLocator,
    removalsByLayer: <int, List<({NodeId nodeId, int nodeIndex})>>{
      found.layerIndex: <({NodeId nodeId, int nodeIndex})>[
        (nodeId: nodeId, nodeIndex: found.nodeIndex),
      ],
    },
  );
  if (removedNodeIds.isEmpty) {
    return null;
  }
  return removed;
}

List<NodeId> txnErasePreparedNodesFromScene({
  required Scene scene,
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
  required Map<int, List<({NodeId nodeId, int nodeIndex})>> removalsByLayer,
}) {
  if (removalsByLayer.isEmpty) {
    return const <NodeId>[];
  }

  final removedNodeIds = <NodeId>[];
  final sortedLayerIndexes = removalsByLayer.keys.toList(growable: false)
    ..sort();
  for (final layerIndex in sortedLayerIndexes) {
    removedNodeIds.addAll(
      _txnErasePreparedNodesFromLayer(
        scene: scene,
        nodeLocator: nodeLocator,
        layerIndex: layerIndex,
        preparedRemovals: removalsByLayer[layerIndex],
      ),
    );
  }
  if (removedNodeIds.isEmpty) {
    return const <NodeId>[];
  }
  return List<NodeId>.unmodifiable(removedNodeIds);
}

List<NodeId> txnEraseNodesFromScene({
  required Scene scene,
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
  required Set<NodeId> nodeIds,
}) {
  if (nodeIds.isEmpty) {
    return const <NodeId>[];
  }

  final removalsByLayer = <int, List<({NodeId nodeId, int nodeIndex})>>{};
  for (final nodeId in nodeIds) {
    final found = locator.txnFindNodeByLocator(
      scene: scene,
      nodeLocator: nodeLocator,
      nodeId: nodeId,
    );
    if (found == null ||
        found.layerIndex == -1 ||
        !isNodeDeletableInLayer(found.node)) {
      continue;
    }
    removalsByLayer
        .putIfAbsent(
          found.layerIndex,
          () => <({NodeId nodeId, int nodeIndex})>[],
        )
        .add((nodeId: found.node.id, nodeIndex: found.nodeIndex));
  }
  return txnErasePreparedNodesFromScene(
    scene: scene,
    nodeLocator: nodeLocator,
    removalsByLayer: removalsByLayer,
  );
}

({List<NodeId> removedNodeIds, bool didStructuralClear})
txnClearSceneKeepBackground({
  required Scene scene,
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
}) {
  final removedNodeIds = <NodeId>[
    for (final layer in scene.layers) ...layer.nodes.map((node) => node.id),
  ];
  var didStructuralClear = false;

  if (scene.backgroundLayer == null) {
    scene.backgroundLayer = BackgroundLayer();
    didStructuralClear = true;
  }
  if (scene.layers.isNotEmpty) {
    scene.layers.clear();
    didStructuralClear = true;
  }
  for (final nodeId in removedNodeIds) {
    nodeLocator.remove(nodeId);
  }
  return (
    removedNodeIds: List<NodeId>.unmodifiable(removedNodeIds),
    didStructuralClear: didStructuralClear,
  );
}

List<NodeId> _txnErasePreparedNodesFromLayer({
  required Scene scene,
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
  required int layerIndex,
  required List<({NodeId nodeId, int nodeIndex})>? preparedRemovals,
}) {
  if (preparedRemovals == null || preparedRemovals.isEmpty) {
    return const <NodeId>[];
  }
  final layerNodes = locator.txnResolveLayerNodes(
    scene: scene,
    layerIndex: layerIndex,
  );
  if (layerNodes == null) {
    return const <NodeId>[];
  }
  final validRemovals = _txnCollectValidPreparedRemovals(
    layerNodes: layerNodes,
    preparedRemovals: preparedRemovals,
  );
  if (validRemovals.isEmpty) {
    return const <NodeId>[];
  }
  final removedNodeIds = _txnEraseValidatedRemovals(
    nodeLocator: nodeLocator,
    layerNodes: layerNodes,
    validRemovals: validRemovals,
  );
  locator.txnWriteLayerNodeLocations(
    locator: nodeLocator,
    layerIndex: layerIndex,
    nodes: layerNodes,
  );
  return removedNodeIds;
}

List<({NodeId nodeId, int nodeIndex})> _txnCollectValidPreparedRemovals({
  required List<SceneNode> layerNodes,
  required List<({NodeId nodeId, int nodeIndex})> preparedRemovals,
}) {
  final validRemovals = <({NodeId nodeId, int nodeIndex})>[];
  final seenRemovalKeys = <(NodeId, int)>{};
  var hasDuplicateRemovals = false;
  for (final removal in preparedRemovals) {
    final nodeIndex = removal.nodeIndex;
    if (nodeIndex < 0 || nodeIndex >= layerNodes.length) {
      continue;
    }
    if (layerNodes[nodeIndex].id != removal.nodeId) {
      continue;
    }
    final removalKey = (removal.nodeId, nodeIndex);
    if (!seenRemovalKeys.add(removalKey)) {
      hasDuplicateRemovals = true;
      continue;
    }
    validRemovals.add(removal);
  }
  assert(
    !hasDuplicateRemovals,
    'Prepared node removals must not contain duplicate nodeId/nodeIndex pairs.',
  );
  validRemovals.sort(
    (left, right) => left.nodeIndex.compareTo(right.nodeIndex),
  );
  return validRemovals;
}

List<NodeId> _txnEraseValidatedRemovals({
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
  required List<SceneNode> layerNodes,
  required List<({NodeId nodeId, int nodeIndex})> validRemovals,
}) {
  final removedNodeIds = validRemovals
      .map((removal) => removal.nodeId)
      .toList(growable: false);
  for (final removal in validRemovals.reversed) {
    layerNodes.removeAt(removal.nodeIndex);
    nodeLocator.remove(removal.nodeId);
  }
  return removedNodeIds;
}
