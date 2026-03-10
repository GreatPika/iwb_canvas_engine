import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/id_generator.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';

void main() {
  test('createInitialIdGeneratorState scans legacy ids into counters', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'node-4', size: const Size(1, 1))],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-3',
          nodes: <SceneNode>[RectNode(id: 'node-9', size: const Size(2, 2))],
        ),
      ],
    );

    final state = createInitialIdGeneratorState(scene);

    expect(state.sessionToken, isNotEmpty);
    expect(state.nextNodeCounter, 10);
    expect(state.nextLayerCounter, 4);
  });

  test('generateNextNodeId and generateNextLayerId use collision barrier', () {
    final state = createIdGeneratorStateForTesting(
      nextNodeCounter: 2,
      nextLayerCounter: 5,
    );

    final nodeId = generateNextNodeId(
      state,
      containsNodeId: (id) => id == 'node-2',
    );
    final layerId = generateNextLayerId(
      state,
      containsLayerId: (id) => id == 'layer-5',
    );

    expect(nodeId, 'node-3');
    expect(layerId, 'layer-6');
    expect(state.nextNodeCounter, 4);
    expect(state.nextLayerCounter, 7);
  });

  test('syncIdGeneratorStateWithSceneLowerBounds preserves session token', () {
    final scene = Scene(
      layers: <ContentLayer>[ContentLayer(id: 'layer-8')],
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'node-11', size: const Size(1, 1))],
      ),
    );
    final state = createIdGeneratorStateForTesting(
      sessionToken: 'session-fixed',
      nextNodeCounter: 1,
      nextLayerCounter: 1,
    );

    syncIdGeneratorStateWithSceneLowerBounds(state, scene);

    expect(state.sessionToken, 'session-fixed');
    expect(state.nextNodeCounter, 12);
    expect(state.nextLayerCounter, 9);
  });

  test('generator rejects negative counters', () {
    final negativeNodeState = createIdGeneratorStateForTesting(
      nextNodeCounter: -1,
      nextLayerCounter: 0,
    );

    expect(
      () => generateNextNodeId(negativeNodeState, containsNodeId: (_) => false),
      throwsA(isA<ArgumentError>()),
    );
  });
}
