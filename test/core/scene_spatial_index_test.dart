import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';

void main() {
  test('query returns de-duplicated candidates across multiple grid cells', () {
    final wideRect = RectNode(
      id: 'wide',
      size: const Size(600, 40),
      fillColor: const Color(0xFF000000),
    )..position = Offset.zero;
    final index = SceneSpatialIndex.build(
      Scene(
        layers: [
          Layer(nodes: [wideRect]),
        ],
      ),
      cellSize: 64,
    );

    final candidates = index.query(const Rect.fromLTRB(-200, -50, 200, 50));
    expect(candidates, hasLength(1));
    expect(candidates.single.node.id, 'wide');
  });

  test('query ignores background-layer nodes', () {
    final backgroundNode = RectNode(
      id: 'bg',
      size: const Size(100, 100),
      fillColor: const Color(0xFF000000),
    );
    final foregroundNode = RectNode(
      id: 'fg',
      size: const Size(100, 100),
      fillColor: const Color(0xFF000000),
    );
    final index = SceneSpatialIndex.build(
      Scene(
        layers: [
          Layer(isBackground: true, nodes: [backgroundNode]),
          Layer(nodes: [foregroundNode]),
        ],
      ),
    );

    final candidates = index.query(const Rect.fromLTRB(-10, -10, 10, 10));
    expect(candidates.map((candidate) => candidate.node.id), ['fg']);
  });

  test('query supports zero-area point probes', () {
    final node = RectNode(
      id: 'node',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(40, 50);
    final index = SceneSpatialIndex.build(
      Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
      cellSize: 32,
    );

    final hitAtCenter = index.query(const Rect.fromLTWH(40, 50, 0, 0));
    expect(hitAtCenter, hasLength(1));
    expect(hitAtCenter.single.node.id, 'node');

    final missFarAway = index.query(const Rect.fromLTWH(400, 500, 0, 0));
    expect(missFarAway, isEmpty);
  });

  test('query returns empty list for non-finite rectangles', () {
    final node = RectNode(
      id: 'node',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    );
    final index = SceneSpatialIndex.build(
      Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );

    final nonFinite = Rect.fromLTWH(double.nan, 0, 10, 10);
    expect(index.query(nonFinite), isEmpty);
  });

  test('invalid cell size falls back to default', () {
    final node = RectNode(
      id: 'node',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    );
    final index = SceneSpatialIndex.build(
      Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
      cellSize: double.nan,
    );

    final candidates = index.query(const Rect.fromLTRB(-15, -15, 15, 15));
    expect(candidates, hasLength(1));
    expect(candidates.single.node.id, 'node');
  });
}
