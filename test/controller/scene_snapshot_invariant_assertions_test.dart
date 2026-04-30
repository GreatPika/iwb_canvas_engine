import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/unsafe_snapshot_materialization.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';

import 'support/scene_snapshot_invariant_assertions.dart';

SceneSnapshot _validSnapshot() {
  return SceneSnapshot(
    backgroundLayer: BackgroundLayerSnapshot(
      nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'bg', size: Size(100, 100))],
    ),
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-0',
        nodes: <NodeSnapshot>[
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

    expect(
      () => assertSceneInvariants(
        snapshot,
        selectedNodeIds: const <NodeId>{'r1'},
      ),
      returnsNormally,
    );
  });

  test('fails on duplicate NodeId across background and content', () {
    final snapshot = unsafeMaterializeSceneSnapshot(
      SceneSnapshotBacking(
        backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'dup', size: const Size(10, 10)),
            ),
          ],
        ),
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-auto-1',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup', size: const Size(10, 10)),
              ),
            ],
          ),
        ],
      ),
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
          id: 'layer-auto-2',
          nodes: <NodeSnapshot>[
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
    final snapshot = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(
          id: 'layer-auto-3',
          nodes: <NodeSnapshot>[
            lineNodeSnapshotFromValidated(
              common: nodeSnapshotCommonFieldsFromValidated(id: 'bad-line'),
              fields: (
                start: const Offset(double.nan, 0),
                end: const Offset(10, 0),
                thickness: 2,
                color: const Color(0xFF000000),
              ),
            ),
          ],
        ),
      ],
    );

    expect(() => assertSceneInvariants(snapshot), throwsA(isA<TestFailure>()));
  });
}
