import '../contract/ids.dart' show LayerId;
import '../core/nodes.dart';
import '../core/scene.dart';
import 'document_locator.dart' as locator;

bool txnInsertNodeInScene({
  required Scene scene,
  required Map<NodeId, ({int layerIndex, int nodeIndex})> nodeLocator,
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

  if (insertedNodeIndex == targetLayer.nodes.length) {
    targetLayer.nodes.add(node);
  } else {
    targetLayer.nodes.insert(insertedNodeIndex, node);
  }
  locator.txnWriteLayerNodeLocations(
    locator: nodeLocator,
    layerIndex: layerIndex,
    nodes: targetLayer.nodes,
    startNodeIndex: insertedNodeIndex,
  );
  return true;
}

int txnResolveInsertLayerIndex({
  required Scene scene,
  LayerId? layerId,
  LayerId Function()? nextLayerId,
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
