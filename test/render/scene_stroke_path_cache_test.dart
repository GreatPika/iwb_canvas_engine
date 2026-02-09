import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  test('P1-1: SceneStrokePathCache caches paths per stroke id', () {
    final cache = SceneStrokePathCache(maxEntries: 8);
    final stroke = StrokeNode(
      id: 's-1',
      points: const [Offset(0, 0), Offset(10, 10)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final path1 = cache.getOrBuild(stroke);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 0);
    expect(cache.debugSize, 1);

    final path2 = cache.getOrBuild(stroke);
    expect(identical(path1, path2), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
    expect(cache.debugSize, 1);
  });

  test('P1-0: SceneStrokePathCache handles dot/empty strokes safely', () {
    final cache = SceneStrokePathCache(maxEntries: 8);
    final dot = StrokeNode(
      id: 'dot',
      points: const [Offset(0, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final empty = StrokeNode(
      id: 'empty',
      points: const <Offset>[],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(() => cache.getOrBuild(dot), returnsNormally);
    expect(() => cache.getOrBuild(empty), returnsNormally);
    expect(cache.debugBuildCount, 0);
  });

  test('P1-2: SceneStrokePathCache rebuilds on geometry change', () {
    final cache = SceneStrokePathCache(maxEntries: 8);
    final stroke = StrokeNode(
      id: 's-1',
      points: [const Offset(0, 0), const Offset(10, 10)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final path1 = cache.getOrBuild(stroke);
    expect(cache.debugBuildCount, 1);

    stroke.points.add(const Offset(20, 20));
    final path2 = cache.getOrBuild(stroke);
    expect(identical(path1, path2), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('P1-2a: SceneStrokePathCache rebuilds on middle-point mutation', () {
    final cache = SceneStrokePathCache(maxEntries: 8);
    final stroke = StrokeNode(
      id: 's-mid',
      points: const [Offset(0, 0), Offset(5, 5), Offset(10, 10)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final path1 = cache.getOrBuild(stroke);
    expect(cache.debugBuildCount, 1);

    stroke.points[1] = const Offset(5, 9);
    final path2 = cache.getOrBuild(stroke);

    expect(identical(path1, path2), isFalse);
    expect(cache.debugBuildCount, 2);
    expect(cache.debugHitCount, 0);
  });

  test('P1-3: SceneStrokePathCache evicts oldest entries (LRU)', () {
    final cache = SceneStrokePathCache(maxEntries: 2);
    final a = StrokeNode(
      id: 'a',
      points: const [Offset(0, 0), Offset(1, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final b = StrokeNode(
      id: 'b',
      points: const [Offset(0, 0), Offset(0, 1)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final c = StrokeNode(
      id: 'c',
      points: const [Offset(1, 1), Offset(2, 2)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    cache.getOrBuild(a);
    cache.getOrBuild(b);
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 0);

    cache.getOrBuild(a); // make A most-recent
    expect(cache.debugHitCount, 1);

    cache.getOrBuild(c); // should evict B
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 1);

    cache.getOrBuild(b); // must rebuild
    expect(cache.debugBuildCount, 4);
  });
}
