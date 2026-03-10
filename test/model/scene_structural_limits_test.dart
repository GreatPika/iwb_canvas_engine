import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/scene_data_exception.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/model/scene_structural_limits.dart';

void main() {
  test('sceneRequireContentLayerLimit accepts boundary and rejects overflow', () {
    expect(
      () => sceneRequireContentLayerLimit(kMaxContentLayersPerScene),
      returnsNormally,
    );

    expect(
      () => sceneRequireContentLayerLimit(kMaxContentLayersPerScene + 1),
      throwsA(
        predicate(
          (error) =>
              error is SceneDataException &&
              error.code == SceneDataErrorCode.invalidValue &&
              error.path == 'layers',
        ),
      ),
    );
  });

  test('sceneConsumeNodeBudget increments to limit and rejects overflow', () {
    expect(
      sceneConsumeNodeBudget(
        totalNodeCount: kMaxNodesPerScene - 1,
        path: 'layers[0].nodes',
      ),
      kMaxNodesPerScene,
    );

    expect(
      () => sceneConsumeNodeBudget(
        totalNodeCount: kMaxNodesPerScene,
        path: 'layers[0].nodes',
      ),
      throwsA(
        predicate(
          (error) =>
              error is SceneDataException &&
              error.code == SceneDataErrorCode.invalidValue &&
              error.path == 'layers[0].nodes',
        ),
      ),
    );
  });
}
