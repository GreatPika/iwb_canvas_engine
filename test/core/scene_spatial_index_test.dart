import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';

void main() {
  Scene sceneWithRect(RectNode node) {
    return Scene(
      layers: <Layer>[
        Layer(nodes: <SceneNode>[node]),
      ],
    );
  }

  RectNode rectCoveringCells({
    required String id,
    required double width,
    required double height,
  }) {
    return RectNode(
      id: id,
      size: Size(width, height),
      transform: Transform2D.translation(Offset(width / 2 + 4, height / 2 + 4)),
    );
  }

  test('huge bounds route node to large candidates and query returns it', () {
    final scene = sceneWithRect(
      RectNode(id: 'huge', size: const Size(1e9, 1e9)),
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.query(const Rect.fromLTWH(0, 0, 10, 10));

    expect(index.debugLargeCandidateCount, 1);
    expect(index.debugCellCount, 0);
    expect(candidates.map((candidate) => candidate.node.id), <NodeId>['huge']);
  });

  test('regular bounds still use grid cells', () {
    final scene = sceneWithRect(
      RectNode(id: 'regular', size: const Size(100, 100)),
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.query(const Rect.fromLTWH(0, 0, 10, 10));

    expect(index.debugLargeCandidateCount, 0);
    expect(index.debugCellCount, greaterThan(0));
    expect(candidates.map((candidate) => candidate.node.id), <NodeId>[
      'regular',
    ]);
  });

  test('boundary: 1024 cells stays grid, 1025 cells goes large', () {
    final exact1024Scene = sceneWithRect(
      rectCoveringCells(id: 'exact-1024', width: 8183, height: 8183),
    );
    final over1024Scene = sceneWithRect(
      rectCoveringCells(id: 'over-1024', width: 8184, height: 8183),
    );

    final exact1024Index = SceneSpatialIndex.build(exact1024Scene);
    final over1024Index = SceneSpatialIndex.build(over1024Scene);

    expect(exact1024Index.debugLargeCandidateCount, 0);
    expect(exact1024Index.debugCellCount, greaterThan(0));
    expect(
      exact1024Index.query(const Rect.fromLTWH(0, 0, 10, 10)).single.node.id,
      'exact-1024',
    );

    expect(over1024Index.debugLargeCandidateCount, 1);
    expect(over1024Index.debugCellCount, 0);
    expect(
      over1024Index.query(const Rect.fromLTWH(0, 0, 10, 10)).single.node.id,
      'over-1024',
    );
  });

  test('huge query switches to fallback candidate scan', () {
    final inside = RectNode(id: 'inside', size: const Size(10, 10));
    final outside = RectNode(id: 'outside', size: const Size(10, 10))
      ..position = const Offset(10000000, 10000000);
    final scene = Scene(
      layers: <Layer>[
        Layer(nodes: <SceneNode>[inside, outside]),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.query(
      const Rect.fromLTWH(-128000, -12800, 256000, 25600),
    );

    final ids = candidates.map((candidate) => candidate.node.id).toSet();
    expect(index.debugFallbackQueryCount, 1);
    expect(ids, contains('inside'));
    expect(ids, isNot(contains('outside')));
  });
}
