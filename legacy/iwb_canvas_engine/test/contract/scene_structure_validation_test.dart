import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/scene_data_exception.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/contract/scene_structure_validation.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show kMaxContentLayersPerScene, kMaxNodesPerScene;

void main() {
  test(
    'sceneRequireContentLayerLimit accepts boundary and rejects overflow',
    () {
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
    },
  );

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

  test(
    'sceneValidateSceneSnapshotBackingStructure reports duplicate node ids',
    () {
      final backing = SceneSnapshotBacking(
        backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'dup', size: const Size(1, 1)),
            ),
          ],
        ),
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-0',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup', size: const Size(2, 2)),
              ),
            ],
          ),
        ],
      );

      expect(
        () => sceneValidateSceneSnapshotBackingStructure(backing),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.code == SceneDataErrorCode.duplicateNodeId &&
                error.path == 'layers[0].nodes[0].id' &&
                error.details['template'] == 'duplicateNodeId',
          ),
        ),
      );
    },
  );

  test(
    'sceneValidateSceneSnapshotBackingStructure reports duplicate layer ids',
    () {
      final backing = SceneSnapshotBacking(
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(id: 'layer-dup'),
          contentLayerSnapshotBackingFromValidated(id: 'layer-dup'),
        ],
      );

      expect(
        () => sceneValidateSceneSnapshotBackingStructure(backing),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.code == SceneDataErrorCode.duplicateLayerId &&
                error.path == 'layers[1].id' &&
                error.details['template'] == 'duplicateLayerId',
          ),
        ),
      );
    },
  );

  test('sceneSnapshotBackingFromValidated accepts valid scene structure', () {
    final backing = sceneSnapshotBackingFromValidated(
      backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
        nodes: <NodeSnapshotBacking>[
          nodeSnapshotBackingOf(
            RectNodeSnapshot(id: 'bg-valid', size: const Size(1, 1)),
          ),
        ],
      ),
      layers: <ContentLayerSnapshotBacking>[
        contentLayerSnapshotBackingFromValidated(
          id: 'layer-valid',
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'node-valid', size: const Size(2, 2)),
            ),
          ],
        ),
      ],
    );

    expect(backing.layers.single.id, 'layer-valid');
    expect(backing.backgroundLayer.nodes.single.id, 'bg-valid');
  });

  test('sceneSnapshotBackingFromValidated rejects duplicate node ids', () {
    expect(
      () => sceneSnapshotBackingFromValidated(
        backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'dup-fast-path', size: const Size(1, 1)),
            ),
          ],
        ),
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-fast-path',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup-fast-path', size: const Size(2, 2)),
              ),
            ],
          ),
        ],
      ),
      throwsA(
        predicate(
          (error) =>
              error is SceneDataException &&
              error.code == SceneDataErrorCode.duplicateNodeId &&
              error.path == 'layers[0].nodes[0].id' &&
              error.details['template'] == 'duplicateNodeId',
        ),
      ),
    );
  });

  test('sceneSnapshotBackingFromValidated rejects duplicate layer ids', () {
    expect(
      () => sceneSnapshotBackingFromValidated(
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(id: 'layer-fast-dup'),
          contentLayerSnapshotBackingFromValidated(id: 'layer-fast-dup'),
        ],
      ),
      throwsA(
        predicate(
          (error) =>
              error is SceneDataException &&
              error.code == SceneDataErrorCode.duplicateLayerId &&
              error.path == 'layers[1].id' &&
              error.details['template'] == 'duplicateLayerId',
        ),
      ),
    );
  });

  test('SceneSnapshotBacking remains the explicit raw backing bypass', () {
    final backing = SceneSnapshotBacking(
      layers: <ContentLayerSnapshotBacking>[
        contentLayerSnapshotBackingFromValidated(id: 'raw-layer'),
        contentLayerSnapshotBackingFromValidated(id: 'raw-layer'),
      ],
    );

    expect(backing.layers, hasLength(2));
    expect(backing.layers.map((layer) => layer.id), <String>[
      'raw-layer',
      'raw-layer',
    ]);
  });
}
