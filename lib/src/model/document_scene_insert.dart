import '../contract/ids.dart' show LayerId;
import '../contract/scene_data_exception.dart';
import '../contract/scene_structure_validation.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/scene_node_locator.dart';
import 'document_locator.dart' as locator;

bool txnEnsureContentLayerInScene({
  required Scene scene,
  required LayerId layerId,
  required Map<LayerId, int> layerIndexById,
  int? insertIndex,
}) {
  if (layerIndexById.containsKey(layerId)) {
    return false;
  }
  txnInsertContentLayerInScene(
    scene: scene,
    layerId: layerId,
    layerIndexById: layerIndexById,
    insertIndex: insertIndex,
  );
  return true;
}

int txnInsertContentLayerInScene({
  required Scene scene,
  required LayerId layerId,
  Map<LayerId, int>? layerIndexById,
  int? insertIndex,
}) {
  final resolvedLayerIndexById =
      layerIndexById ?? locator.txnBuildLayerIndexById(scene);
  sceneRequireContentLayerLimit(scene.layers.length + 1);
  final resolvedInsertIndex = insertIndex ?? scene.layers.length;
  if (resolvedInsertIndex < 0 || resolvedInsertIndex > scene.layers.length) {
    throw RangeError.range(
      resolvedInsertIndex,
      0,
      scene.layers.length,
      'insertIndex',
    );
  }
  _txnRequireUniqueLayerId(
    layerId: layerId,
    layerIndexById: resolvedLayerIndexById,
    targetPath: 'layers[$resolvedInsertIndex].id',
  );

  scene.layers.insert(resolvedInsertIndex, ContentLayer(id: layerId));
  for (final entry in resolvedLayerIndexById.entries.toList(growable: false)) {
    if (entry.value >= resolvedInsertIndex) {
      resolvedLayerIndexById[entry.key] = entry.value + 1;
    }
  }
  resolvedLayerIndexById[layerId] = resolvedInsertIndex;
  return resolvedInsertIndex;
}

void txnReplaceContentLayerInScene({
  required Scene scene,
  required int layerIndex,
  required ContentLayer layer,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
  Map<LayerId, int>? layerIndexById,
}) {
  final resolvedNodeLocator = nodeLocator ?? locator.txnBuildNodeLocator(scene);
  final resolvedLayerIndexById =
      layerIndexById ?? locator.txnBuildLayerIndexById(scene);
  final previous = _txnRequireValidLayerIndex(
    scene: scene,
    layerIndex: layerIndex,
  );
  final existingIndex = resolvedLayerIndexById[layer.id];
  if (existingIndex != null && existingIndex != layerIndex) {
    throw SceneDataException.duplicateLayerId(
      path: 'layers[$layerIndex].id',
      layerId: layer.id,
    );
  }

  scene.layers[layerIndex] = layer;
  if (previous.id != layer.id) {
    resolvedLayerIndexById.remove(previous.id);
    resolvedLayerIndexById[layer.id] = layerIndex;
  }
  for (final node in previous.nodes) {
    resolvedNodeLocator.remove(node.id);
  }
  locator.txnWriteLayerNodeLocations(
    locator: resolvedNodeLocator,
    nodes: layer.nodes,
    contentLayerId: layer.id,
  );
}

void txnReplaceContentLayerSlotInScene({
  required Scene scene,
  required int layerIndex,
  required ContentLayer layer,
}) {
  _txnRequireValidLayerIndex(scene: scene, layerIndex: layerIndex);
  scene.layers[layerIndex] = layer;
}

bool txnInsertNodeInScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required SceneNode node,
  required int layerIndex,
  int? insertIndex,
}) {
  if (nodeLocator.containsKey(node.id)) {
    throw StateError('Node id must be unique: ${node.id}');
  }
  if (layerIndex < 0 || layerIndex >= scene.layers.length) {
    throw RangeError.range(
      layerIndex,
      0,
      scene.layers.length - 1,
      'layerIndex',
    );
  }

  final targetLayer = scene.layers[layerIndex];
  final insertedNodeIndex = insertIndex ?? targetLayer.nodes.length;
  if (insertedNodeIndex < 0 || insertedNodeIndex > targetLayer.nodes.length) {
    throw RangeError.range(
      insertedNodeIndex,
      0,
      targetLayer.nodes.length,
      'insertIndex',
    );
  }
  sceneConsumeNodeBudget(
    totalNodeCount: nodeLocator.length,
    path: 'layers[$layerIndex].nodes',
  );

  if (insertedNodeIndex == targetLayer.nodes.length) {
    targetLayer.nodes.add(node);
  } else {
    targetLayer.nodes.insert(insertedNodeIndex, node);
  }
  locator.txnWriteLayerNodeLocations(
    locator: nodeLocator,
    contentLayerId: targetLayer.id,
    nodes: targetLayer.nodes,
    startNodeIndex: insertedNodeIndex,
  );
  return true;
}

int txnResolveInsertLayerIndex({
  required Scene scene,
  LayerId? layerId,
  LayerId Function()? nextLayerId,
  Map<LayerId, int>? layerIndexById,
}) {
  if (layerId != null) {
    final index = txnFindContentLayerIndexById(scene: scene, layerId: layerId);
    if (index == null) {
      throw ArgumentError.value(
        layerId,
        'layerId',
        'Unknown content layer id.',
      );
    }
    return index;
  }
  if (scene.layers.isEmpty) {
    final generatedId = nextLayerId == null ? 'layer-0' : nextLayerId();
    if (layerIndexById != null) {
      return txnInsertContentLayerInScene(
        scene: scene,
        layerId: generatedId,
        layerIndexById: layerIndexById,
      );
    }
    sceneRequireContentLayerLimit(scene.layers.length + 1);
    scene.layers.add(ContentLayer(id: generatedId));
    return 0;
  }
  return scene.layers.length - 1;
}

int? txnFindContentLayerIndexById({
  required Scene scene,
  required LayerId layerId,
}) {
  for (var index = 0; index < scene.layers.length; index++) {
    if (scene.layers[index].id == layerId) {
      return index;
    }
  }
  return null;
}

ContentLayer _txnRequireValidLayerIndex({
  required Scene scene,
  required int layerIndex,
}) {
  if (layerIndex < 0 || layerIndex >= scene.layers.length) {
    throw RangeError.range(
      layerIndex,
      0,
      scene.layers.length - 1,
      'layerIndex',
    );
  }
  return scene.layers[layerIndex];
}

void _txnRequireUniqueLayerId({
  required LayerId layerId,
  required Map<LayerId, int> layerIndexById,
  required String targetPath,
}) {
  if (layerIndexById.containsKey(layerId)) {
    throw SceneDataException.duplicateLayerId(
      path: targetPath,
      layerId: layerId,
    );
  }
}
