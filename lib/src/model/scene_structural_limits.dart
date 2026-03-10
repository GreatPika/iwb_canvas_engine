import '../contract/scene_data_exception.dart';
import '../core/scene_limits.dart';

void sceneRequireContentLayerLimit(int layerCount) {
  if (layerCount <= kMaxContentLayersPerScene) {
    return;
  }
  throw SceneDataException.maxItems(
    path: 'layers',
    maxItems: kMaxContentLayersPerScene,
    source: layerCount,
  );
}

int sceneConsumeNodeBudget({
  required int totalNodeCount,
  required String path,
}) {
  final nextTotalNodeCount = totalNodeCount + 1;
  if (nextTotalNodeCount <= kMaxNodesPerScene) {
    return nextTotalNodeCount;
  }
  throw SceneDataException.maxNodes(
    path: path,
    maxNodes: kMaxNodesPerScene,
    source: nextTotalNodeCount,
  );
}
