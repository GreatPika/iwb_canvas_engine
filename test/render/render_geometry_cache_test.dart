import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';
import 'package:iwb_canvas_engine/src/public/node_patch.dart';
import 'package:iwb_canvas_engine/src/public/patch_field.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';

// INV:INV-V2-RENDER-GEOMETRY-KEY-STABLE
void main() {
  test('RenderGeometryCache rejects non-positive maxEntries', () {
    expect(() => RenderGeometryCache(maxEntries: 0), throwsArgumentError);
    expect(() => RenderGeometryCache(maxEntries: -1), throwsArgumentError);
  });

  test('RenderGeometryCache reuses entry for unchanged node geometry', () {
    final cache = RenderGeometryCache();
    const node = RectNodeSnapshot(
      id: 'rect-1',
      size: Size(20, 10),
      strokeColor: Color(0xFF000000),
      strokeWidth: 2,
    );

    final entry1 = cache.get(node);
    final entry2 = cache.get(node);

    expect(identical(entry1, entry2), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
    expect(cache.debugSize, 1);
  });

  test(
    'RenderGeometryCache treats same id with different instanceRevision as different entries',
    () {
      final cache = RenderGeometryCache();
      const oldNode = RectNodeSnapshot(
        id: 'reuse-id',
        instanceRevision: 1,
        size: Size(20, 10),
      );
      const newNode = RectNodeSnapshot(
        id: 'reuse-id',
        instanceRevision: 2,
        size: Size(20, 10),
      );

      final oldEntry = cache.get(oldNode);
      final newEntry = cache.get(newNode);
      final newEntryHit = cache.get(newNode);

      expect(identical(oldEntry, newEntry), isFalse);
      expect(identical(newEntry, newEntryHit), isTrue);
      expect(cache.debugBuildCount, 2);
      expect(cache.debugHitCount, 1);
      expect(cache.debugSize, 2);
    },
  );

  test(
    'RenderGeometryCache hits for equivalent stroke snapshots with stable revision/scalars',
    () {
      final cache = RenderGeometryCache();
      final strokeA = StrokeNodeSnapshot(
        id: 'stroke-eq',
        instanceRevision: 7,
        points: const <Offset>[Offset(0, 0), Offset(10, 5), Offset(20, 5)],
        pointsRevision: 11,
        thickness: 3,
        color: const Color(0xFF000000),
      );
      final strokeA2 = StrokeNodeSnapshot(
        id: 'stroke-eq',
        instanceRevision: 7,
        points: const <Offset>[Offset(0, 0), Offset(10, 5), Offset(20, 5)],
        pointsRevision: 11,
        thickness: 3,
        color: const Color(0xFF000000),
      );

      final entryA = cache.get(strokeA);
      final entryA2 = cache.get(strokeA2);

      expect(identical(entryA, entryA2), isTrue);
      expect(cache.debugBuildCount, 1);
      expect(cache.debugHitCount, 1);
    },
  );

  test(
    'RenderGeometryCache rebuilds stroke entry when pointsRevision changes',
    () {
      final cache = RenderGeometryCache();
      final strokeA = StrokeNodeSnapshot(
        id: 'stroke-rev',
        instanceRevision: 9,
        points: const <Offset>[Offset(0, 0), Offset(10, 5), Offset(20, 5)],
        pointsRevision: 11,
        thickness: 3,
        color: const Color(0xFF000000),
      );
      final strokeChanged = StrokeNodeSnapshot(
        id: 'stroke-rev',
        instanceRevision: 9,
        points: const <Offset>[Offset(0, 0), Offset(10, 5), Offset(20, 5)],
        pointsRevision: 12,
        thickness: 3,
        color: const Color(0xFF000000),
      );

      final entryA = cache.get(strokeA);
      final entryChanged = cache.get(strokeChanged);

      expect(identical(entryA, entryChanged), isFalse);
      expect(cache.debugBuildCount, 2);
      expect(cache.debugHitCount, 0);
    },
  );

  test(
    'RenderGeometryCache keeps hit for unchanged stroke across unrelated controller commit',
    () {
      // pointsRevision monotonicity itself is asserted in scene_controller_test.
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 's',
                  points: const <Offset>[Offset(0, 0), Offset(10, 0)],
                  pointsRevision: 3,
                  thickness: 2,
                  color: const Color(0xFF000000),
                ),
                const RectNodeSnapshot(id: 'r', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final cache = RenderGeometryCache();
      final strokeBefore =
          controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot;
      cache.get(strokeBefore);

      controller.write<void>((writer) {
        writer.writeNodePatch(
          const RectNodePatch(
            id: 'r',
            size: PatchField<Size>.value(Size(20, 20)),
          ),
        );
      });

      final strokeAfter =
          controller.snapshot.layers.first.nodes.first as StrokeNodeSnapshot;
      cache.get(strokeAfter);

      expect(cache.debugBuildCount, 1);
      expect(cache.debugHitCount, 1);
    },
  );

  test('RenderGeometryCache rebuilds when path geometry key changes', () {
    final cache = RenderGeometryCache();
    const nodeA = PathNodeSnapshot(id: 'path-1', svgPathData: 'M0 0 H10');
    const nodeB = PathNodeSnapshot(id: 'path-1', svgPathData: 'M0 0 H20');

    final entryA = cache.get(nodeA);
    final entryB = cache.get(nodeB);

    expect(identical(entryA, entryB), isFalse);
    expect(cache.debugBuildCount, 2);
    expect(cache.debugHitCount, 0);
  });

  test('RenderGeometryCache rect bounds include stroke only when enabled', () {
    final cache = RenderGeometryCache();
    const withStroke = RectNodeSnapshot(
      id: 'rect-with-stroke',
      size: Size(10, 6),
      strokeColor: Color(0xFF000000),
      strokeWidth: 4,
    );
    const noStroke = RectNodeSnapshot(
      id: 'rect-no-stroke',
      size: Size(10, 6),
      strokeWidth: 4,
    );

    final withStrokeEntry = cache.get(withStroke);
    final noStrokeEntry = cache.get(noStroke);

    expect(withStrokeEntry.localBounds, const Rect.fromLTRB(-7, -5, 7, 5));
    expect(noStrokeEntry.localBounds, const Rect.fromLTRB(-5, -3, 5, 3));
  });

  test('RenderGeometryCache path bounds include stroke only when enabled', () {
    final cache = RenderGeometryCache();
    const withStroke = PathNodeSnapshot(
      id: 'path-with-stroke',
      svgPathData: 'M0 0 H10 V10 H0 Z',
      strokeColor: Color(0xFF000000),
      strokeWidth: 4,
    );
    const noStroke = PathNodeSnapshot(
      id: 'path-no-stroke',
      svgPathData: 'M0 0 H10 V10 H0 Z',
      strokeWidth: 4,
    );

    final withStrokeEntry = cache.get(withStroke);
    final noStrokeEntry = cache.get(noStroke);

    expect(withStrokeEntry.localBounds, const Rect.fromLTRB(-7, -7, 7, 7));
    expect(noStrokeEntry.localBounds, const Rect.fromLTRB(-5, -5, 5, 5));
  });

  test(
    'RenderGeometryCache ignores strokeWidth key changes when stroke is disabled',
    () {
      final cache = RenderGeometryCache();
      const nodeA = PathNodeSnapshot(
        id: 'path-disabled-stroke',
        svgPathData: 'M0 0 H10 V10 H0 Z',
        strokeWidth: 1,
      );
      const nodeB = PathNodeSnapshot(
        id: 'path-disabled-stroke',
        svgPathData: 'M0 0 H10 V10 H0 Z',
        strokeWidth: 64,
      );

      final entryA = cache.get(nodeA);
      final entryB = cache.get(nodeB);

      expect(identical(entryA, entryB), isTrue);
      expect(entryB.localBounds, const Rect.fromLTRB(-5, -5, 5, 5));
      expect(cache.debugBuildCount, 1);
      expect(cache.debugHitCount, 1);
    },
  );

  test('RenderGeometryCache rebuilds when path stroke enablement changes', () {
    final cache = RenderGeometryCache();
    const nodeWithoutStroke = PathNodeSnapshot(
      id: 'path-enable-stroke',
      svgPathData: 'M0 0 H10 V10 H0 Z',
      strokeWidth: 4,
    );
    const nodeWithStroke = PathNodeSnapshot(
      id: 'path-enable-stroke',
      svgPathData: 'M0 0 H10 V10 H0 Z',
      strokeColor: Color(0xFF000000),
      strokeWidth: 4,
    );

    final withoutStrokeEntry = cache.get(nodeWithoutStroke);
    final withStrokeEntry = cache.get(nodeWithStroke);

    expect(identical(withoutStrokeEntry, withStrokeEntry), isFalse);
    expect(withoutStrokeEntry.localBounds, const Rect.fromLTRB(-5, -5, 5, 5));
    expect(withStrokeEntry.localBounds, const Rect.fromLTRB(-7, -7, 7, 7));
    expect(cache.debugBuildCount, 2);
    expect(cache.debugHitCount, 0);
  });

  test('RenderGeometryCache builds centered path and world bounds', () {
    final cache = RenderGeometryCache();
    const node = PathNodeSnapshot(
      id: 'path-centered',
      svgPathData: 'M0 0 H10 V10 H0 Z',
      strokeColor: Color(0xFF000000),
      strokeWidth: 2,
      transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 20),
    );

    final entry = cache.get(node);

    expect(entry.localPath, isNotNull);
    expect(entry.localBounds, const Rect.fromLTRB(-6, -6, 6, 6));
    expect(entry.worldBounds, const Rect.fromLTRB(4, 14, 16, 26));
  });

  test(
    'RenderGeometryCache returns safe zero bounds for invalid path data',
    () {
      final cache = RenderGeometryCache();
      const node = PathNodeSnapshot(id: 'path-invalid', svgPathData: 'invalid');

      final entry = cache.get(node);

      expect(entry.localPath, isNull);
      expect(entry.localBounds, Rect.zero);
      expect(entry.worldBounds, Rect.zero);
    },
  );

  test(
    'RenderGeometryCache returns zero world bounds for non-finite transform',
    () {
      final cache = RenderGeometryCache();
      final node = RectNodeSnapshot(
        id: 'rect-non-finite-transform',
        size: const Size(10, 10),
        transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: double.nan, ty: 0),
      );

      final entry = cache.get(node);

      expect(entry.localBounds, const Rect.fromLTRB(-5, -5, 5, 5));
      expect(entry.worldBounds, Rect.zero);
    },
  );

  test('RenderGeometryCache invalidateAll clears cached entries', () {
    final cache = RenderGeometryCache();
    const node = ImageNodeSnapshot(
      id: 'image-1',
      imageId: 'img',
      size: Size(20, 20),
    );

    cache.get(node);
    expect(cache.debugSize, 1);

    cache.invalidateAll();
    expect(cache.debugSize, 0);

    cache.get(node);
    expect(cache.debugBuildCount, 2);
  });

  test('RenderGeometryCache evicts least recently used entry', () {
    final cache = RenderGeometryCache(maxEntries: 2);
    const nodeA = RectNodeSnapshot(id: 'rect-a', size: Size(8, 8));
    const nodeB = RectNodeSnapshot(id: 'rect-b', size: Size(8, 8));
    const nodeC = RectNodeSnapshot(id: 'rect-c', size: Size(8, 8));

    cache.get(nodeA);
    cache.get(nodeB);
    cache.get(nodeC);

    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 1);

    cache.get(nodeA);
    expect(cache.debugBuildCount, 4);
  });

  test(
    'RenderGeometryCache cache hit refreshes recency and keeps entry in cache',
    () {
      final cache = RenderGeometryCache(maxEntries: 2);
      const nodeA = RectNodeSnapshot(id: 'rect-a', size: Size(8, 8));
      const nodeB = RectNodeSnapshot(id: 'rect-b', size: Size(8, 8));
      const nodeC = RectNodeSnapshot(id: 'rect-c', size: Size(8, 8));

      cache.get(nodeA);
      cache.get(nodeB);
      cache.get(nodeA); // refresh A recency
      cache.get(nodeC); // should evict B
      cache.get(nodeA); // A must still be cached

      expect(cache.debugSize, 2);
      expect(cache.debugBuildCount, 3);
      expect(cache.debugHitCount, 2);
      expect(cache.debugEvictCount, 1);

      cache.get(nodeB);
      expect(cache.debugBuildCount, 4);
      expect(cache.debugEvictCount, 2);
    },
  );

  test('RenderGeometryCache stays bounded under heavy node-id churn', () {
    final cache = RenderGeometryCache(maxEntries: 64);
    for (var i = 0; i < 5000; i++) {
      cache.get(RectNodeSnapshot(id: 'node-$i', size: const Size(10, 10)));
    }

    expect(cache.debugSize, 64);
    expect(cache.debugBuildCount, 5000);
    expect(cache.debugEvictCount, 4936);
  });
}
