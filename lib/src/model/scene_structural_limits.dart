import '../contract/scene_data_exception.dart';
import '../core/scene_limits.dart';

void sceneRequireContentLayerLimit(int layerCount) {
  if (layerCount <= kMaxContentLayersPerScene) {
    return;
  }
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: 'layers',
    message:
        'Field layers must contain at most $kMaxContentLayersPerScene items.',
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
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: path,
    message: 'Scene must contain at most $kMaxNodesPerScene nodes.',
    source: nextTotalNodeCount,
  );
}
