import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'scene_invariants.dart';

SceneSnapshot _validSnapshot() {
  return SceneSnapshot(
    backgroundLayer: BackgroundLayerSnapshot(
      nodes: const <NodeSnapshot>[
        RectNodeSnapshot(id: 'bg', size: Size(100, 100)),
      ],
    ),
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        nodes: const <NodeSnapshot>[
          RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
          LineNodeSnapshot(
            id: 'l1',
            start: Offset(0, 0),
            end: Offset(10, 0),
            thickness: 2,
            color: Color(0xFF000000),
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('assertSceneInvariants passes on valid typed snapshot', () {
    final snapshot = _validSnapshot();

    assertSceneInvariants(snapshot, selectedNodeIds: const <NodeId>{'r1'});
  });

  test('fails on duplicate NodeId across background and content', () {
    final snapshot = SceneSnapshot(
      backgroundLayer: BackgroundLayerSnapshot(
        nodes: const <NodeSnapshot>[
          RectNodeSnapshot(id: 'dup', size: Size(10, 10)),
        ],
      ),
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(id: 'dup', size: Size(10, 10)),
          ],
        ),
      ],
    );

    expect(() => assertSceneInvariants(snapshot), throwsA(isA<TestFailure>()));
  });

  test('fails when selection contains background node id', () {
    final snapshot = _validSnapshot();

    expect(
      () => assertSceneInvariants(snapshot, selectedNodeIds: const {'bg'}),
      throwsA(isA<TestFailure>()),
    );
  });

  test('fails when selection contains invisible content node', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'hidden',
              size: Size(10, 10),
              isVisible: false,
            ),
          ],
        ),
      ],
    );

    expect(
      () => assertSceneInvariants(snapshot, selectedNodeIds: const {'hidden'}),
      throwsA(isA<TestFailure>()),
    );
  });

  test('fails on non finite geometry', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: const <NodeSnapshot>[
            LineNodeSnapshot(
              id: 'bad-line',
              start: Offset(double.nan, 0),
              end: Offset(10, 0),
              thickness: 2,
              color: Color(0xFF000000),
            ),
          ],
        ),
      ],
    );

    expect(() => assertSceneInvariants(snapshot), throwsA(isA<TestFailure>()));
  });
}
