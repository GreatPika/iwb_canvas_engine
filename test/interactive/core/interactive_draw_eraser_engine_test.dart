import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_eraser_engine.dart';

void main() {
  test('eraser fallback handles singular line transform with single point', () {
    final line = LineNode(
      id: 'line',
      start: const Offset(-20, 0),
      end: const Offset(20, 0),
      thickness: 2,
      color: const Color(0xFF000000),
      transform: const Transform2D(a: 1, b: 2, c: 2, d: 4, tx: 120, ty: 80),
    );
    final candidate = SceneSpatialCandidate(
      layerIndex: 0,
      nodeIndex: 0,
      node: line,
      candidateBoundsWorld: line.boundsWorld,
    );
    final removedIds = <String>[];

    final engine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onStateChanged: () {},
        querySpatialCandidates: (_) => <SceneSpatialCandidate>[candidate],
        resolveSpatialCandidateNode: (c) => c.node,
        writeEraseNodes: (ids) {
          removedIds.addAll(ids);
          return ids.length;
        },
      ),
    );

    engine.handleDown(const Offset(120, 80));
    final erased = engine.commitOnUp(
      const Offset(120, 80),
      eraserThickness: 30,
    );

    expect(erased, <String>['line']);
    expect(removedIds, <String>['line']);
  });

  test('eraser fallback handles singular stroke transform with segment', () {
    final stroke = StrokeNode(
      id: 'stroke',
      points: const <Offset>[Offset(-15, 0), Offset(15, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
      transform: const Transform2D(a: 1, b: 2, c: 2, d: 4, tx: 180, ty: 80),
    );
    final candidate = SceneSpatialCandidate(
      layerIndex: 0,
      nodeIndex: 0,
      node: stroke,
      candidateBoundsWorld: stroke.boundsWorld,
    );
    final removedIds = <String>[];

    final engine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onStateChanged: () {},
        querySpatialCandidates: (_) => <SceneSpatialCandidate>[candidate],
        resolveSpatialCandidateNode: (c) => c.node,
        writeEraseNodes: (ids) {
          removedIds.addAll(ids);
          return ids.length;
        },
      ),
    );

    engine.handleDown(const Offset(170, 80));
    engine.handleMove(const Offset(190, 80));
    final erased = engine.commitOnUp(
      const Offset(190, 80),
      eraserThickness: 30,
    );

    expect(erased, <String>['stroke']);
    expect(removedIds, <String>['stroke']);
  });
}
