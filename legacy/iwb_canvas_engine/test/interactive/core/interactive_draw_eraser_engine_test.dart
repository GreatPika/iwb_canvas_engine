import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/node_geometry.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_eraser_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_eraser_projection.dart';

void main() {
  test('eraser projection contract stays usable across focused owners', () {
    final InteractiveDrawProjectedEraser projected = (
      points: const <Offset>[Offset.zero],
      threshold: 3.0,
      thresholdSquared: 9.0,
    );

    expect(projected.points, const <Offset>[Offset.zero]);
    expect(projected.threshold, 3.0);
    expect(projected.thresholdSquared, 9.0);
  });

  test('eraser fallback handles singular line transform with single point', () {
    final line = _RawTransformLineNode(
      id: 'line',
      start: const Offset(-20, 0),
      end: const Offset(20, 0),
      thickness: 2,
      color: const Color(0xFF000000),
      rawTransform: const Transform2D(a: 1, b: 2, c: 2, d: 4, tx: 120, ty: 80),
    );
    final candidate = SceneHitTestSpatialCandidate(
      nodeId: line.id,
      layerIndex: 0,
      nodeIndex: 0,
      structuralRevision: 0,
      hitTestBoundsWorld: nodeSnapshotBoundsWorld(line),
    );
    final removedIds = <String>[];

    final engine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onOverlayStateChanged: () {},
        queryHitTestCandidates: (_) => <SceneHitTestSpatialCandidate>[
          candidate,
        ],
        resolveSpatialCandidateSnapshot: (location) =>
            location.layerIndex == candidate.layerIndex &&
                location.nodeIndex == candidate.nodeIndex
            ? line
            : null,
        commitEraseNodes: (ids) {
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
    expect(engine.debugEraserProjectedPointCount, 0);
  });

  test('eraser projected hit counts materialized local points', () {
    final line = LineNodeSnapshot(
      id: 'line',
      start: const Offset(-20, 0),
      end: const Offset(20, 0),
      thickness: 2,
      color: const Color(0xFF000000),
      transform: Transform2D.translation(const Offset(120, 80)),
    );
    final candidate = SceneHitTestSpatialCandidate(
      nodeId: line.id,
      layerIndex: 0,
      nodeIndex: 0,
      structuralRevision: 0,
      hitTestBoundsWorld: nodeSnapshotBoundsWorld(line),
    );

    final engine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onOverlayStateChanged: () {},
        queryHitTestCandidates: (_) => <SceneHitTestSpatialCandidate>[
          candidate,
        ],
        resolveSpatialCandidateSnapshot: (location) =>
            location.layerIndex == candidate.layerIndex &&
                location.nodeIndex == candidate.nodeIndex
            ? line
            : null,
        commitEraseNodes: (ids) => ids.length,
      ),
    );

    engine.handleDown(const Offset(100, 80));
    final erased = engine.commitOnUp(
      const Offset(140, 80),
      eraserThickness: 30,
    );

    expect(erased, <String>['line']);
    expect(engine.debugEraserProjectedPointCount, 2);
  });

  test('eraser fallback handles singular stroke transform with segment', () {
    final stroke = _RawTransformStrokeNode(
      id: 'stroke',
      points: const <Offset>[Offset(-15, 0), Offset(15, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
      rawTransform: const Transform2D(a: 1, b: 2, c: 2, d: 4, tx: 180, ty: 80),
    );
    final candidate = SceneHitTestSpatialCandidate(
      nodeId: stroke.id,
      layerIndex: 0,
      nodeIndex: 0,
      structuralRevision: 0,
      hitTestBoundsWorld: nodeSnapshotBoundsWorld(stroke),
    );
    final removedIds = <String>[];

    final engine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onOverlayStateChanged: () {},
        queryHitTestCandidates: (_) => <SceneHitTestSpatialCandidate>[
          candidate,
        ],
        resolveSpatialCandidateSnapshot: (location) =>
            location.layerIndex == candidate.layerIndex &&
                location.nodeIndex == candidate.nodeIndex
            ? stroke
            : null,
        commitEraseNodes: (ids) {
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
    expect(engine.debugEraserProjectedPointCount, 0);
  });

  test('eraser keeps undeletable nodes even when geometry matches', () {
    final line = LineNodeSnapshot(
      id: 'line',
      start: const Offset(-20, 0),
      end: const Offset(20, 0),
      thickness: 2,
      color: const Color(0xFF000000),
      isDeletable: false,
      transform: Transform2D.translation(const Offset(120, 80)),
    );
    final candidate = SceneHitTestSpatialCandidate(
      nodeId: line.id,
      layerIndex: 0,
      nodeIndex: 0,
      structuralRevision: 0,
      hitTestBoundsWorld: nodeSnapshotBoundsWorld(line),
    );
    final removedIds = <String>[];

    final engine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onOverlayStateChanged: () {},
        queryHitTestCandidates: (_) => <SceneHitTestSpatialCandidate>[
          candidate,
        ],
        resolveSpatialCandidateSnapshot: (location) =>
            location.layerIndex == candidate.layerIndex &&
                location.nodeIndex == candidate.nodeIndex
            ? line
            : null,
        commitEraseNodes: (ids) {
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

    expect(erased, isEmpty);
    expect(removedIds, isEmpty);
  });
}

final class _RawTransformLineNode extends LineNodeSnapshot {
  _RawTransformLineNode({
    required super.id,
    required super.start,
    required super.end,
    required super.thickness,
    required super.color,
    required Transform2D rawTransform,
  }) : _rawTransform = rawTransform;

  final Transform2D _rawTransform;

  @override
  Transform2D get transform => _rawTransform;
}

final class _RawTransformStrokeNode extends StrokeNodeSnapshot {
  _RawTransformStrokeNode({
    required super.id,
    required super.points,
    required super.thickness,
    required super.color,
    required Transform2D rawTransform,
  }) : _rawTransform = rawTransform;

  final Transform2D _rawTransform;

  @override
  Transform2D get transform => _rawTransform;
}
