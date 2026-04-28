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
  if (txnFindContentLayerIndexById(scene: scene, layerId: layerId) != null) {
    _txnRefreshLayerIndexById(scene: scene, layerIndexById: layerIndexById);
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
    scene: scene,
    targetPath: 'layers[$resolvedInsertIndex].id',
  );

  scene.layers.insert(resolvedInsertIndex, ContentLayer(id: layerId));
  if (layerIndexById != null) {
    _txnRefreshLayerIndexById(scene: scene, layerIndexById: layerIndexById);
  }
  return resolvedInsertIndex;
}

void txnReplaceContentLayerSlotInScene({
  required Scene scene,
  required int layerIndex,
  required ContentLayer layer,
}) {
  final previous = _txnRequireValidLayerIndex(
    scene: scene,
    layerIndex: layerIndex,
  );
  _txnRequireSlotReplacementPreservesTopology(previous: previous, layer: layer);
  scene.layers[layerIndex] = layer;
}

bool txnInsertNodeInScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required SceneNode node,
  required int layerIndex,
  int? insertIndex,
}) {
  if (locator.txnFindNodeById(scene, node.id) != null) {
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
    totalNodeCount: _txnCountSceneNodes(scene),
    path: 'layers[$layerIndex].nodes',
  );

  if (insertedNodeIndex == targetLayer.nodes.length) {
    targetLayer.nodes.add(node);
  } else {
    targetLayer.nodes.insert(insertedNodeIndex, node);
  }
  _txnRefreshNodeLocator(scene: scene, nodeLocator: nodeLocator);
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
  required Scene scene,
  required String targetPath,
}) {
  if (txnFindContentLayerIndexById(scene: scene, layerId: layerId) != null) {
    throw SceneDataException.duplicateLayerId(
      path: targetPath,
      layerId: layerId,
    );
  }
}

int _txnCountSceneNodes(Scene scene) {
  var totalNodeCount = scene.backgroundLayer?.nodes.length ?? 0;
  for (final layer in scene.layers) {
    totalNodeCount += layer.nodes.length;
  }
  return totalNodeCount;
}

void _txnRefreshNodeLocator({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
}) {
  nodeLocator
    ..clear()
    ..addAll(locator.txnBuildNodeLocator(scene));
}

void _txnRefreshLayerIndexById({
  required Scene scene,
  required Map<LayerId, int> layerIndexById,
}) {
  layerIndexById
    ..clear()
    ..addAll(locator.txnBuildLayerIndexById(scene));
}

void _txnRequireSlotReplacementPreservesTopology({
  required ContentLayer previous,
  required ContentLayer layer,
}) {
  if (layer.id != previous.id) {
    throw StateError('Slot replacement must preserve layer.id.');
  }
  if (layer.nodes.length != previous.nodes.length) {
    throw StateError('Slot replacement must preserve node count.');
  }
  for (var index = 0; index < previous.nodes.length; index++) {
    if (!identical(layer.nodes[index], previous.nodes[index])) {
      throw StateError(
        'Slot replacement must preserve per-index node identity.',
      );
    }
  }
}
