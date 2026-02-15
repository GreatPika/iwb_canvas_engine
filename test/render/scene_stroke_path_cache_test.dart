import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

void main() {
  test('v2 stroke cache rejects non-positive maxEntries', () {
    expect(() => SceneStrokePathCache(maxEntries: 0), throwsArgumentError);
    expect(() => SceneStrokePathCache(maxEntries: -1), throwsArgumentError);
  });

  test('v2 stroke cache handles empty/dot geometries safely', () {
    final cache = SceneStrokePathCache(maxEntries: 8);
    final empty = StrokeNodeSnapshot(
      id: 'empty',
      points: const <Offset>[],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final dot = StrokeNodeSnapshot(
      id: 'dot',
      points: const <Offset>[Offset(0, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    expect(() => cache.getOrBuild(empty), returnsNormally);
    expect(() => cache.getOrBuild(dot), returnsNormally);
    expect(cache.debugBuildCount, 0);
  });

  test('v2 stroke cache rebuilds only when pointsRevision changes', () {
    final cache = SceneStrokePathCache(maxEntries: 8);
    final strokeA = StrokeNodeSnapshot(
      id: 's1',
      points: const <Offset>[Offset(0, 0), Offset(10, 10)],
      pointsRevision: 1,
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final strokeA2 = StrokeNodeSnapshot(
      id: 's1',
      points: const <Offset>[Offset(0, 0), Offset(10, 10)],
      pointsRevision: 1,
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final strokeChanged = StrokeNodeSnapshot(
      id: 's1',
      points: const <Offset>[Offset(0, 0), Offset(10, 10)],
      pointsRevision: 2,
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final staleRevision = StrokeNodeSnapshot(
      id: 's1',
      points: const <Offset>[Offset(0, 0), Offset(12, 10)],
      pointsRevision: 2,
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final first = cache.getOrBuild(strokeA);
    final second = cache.getOrBuild(strokeA2);
    final third = cache.getOrBuild(strokeChanged);
    final fourth = cache.getOrBuild(staleRevision);

    expect(identical(first, second), isTrue);
    expect(identical(second, third), isFalse);
    expect(identical(third, fourth), isTrue);
    expect(cache.debugBuildCount, 2);
    expect(cache.debugHitCount, 2);
  });

  test(
    'v2 stroke cache treats same id with different instanceRevision as different entries',
    () {
      final cache = SceneStrokePathCache(maxEntries: 8);
      final oldNode = StrokeNodeSnapshot(
        id: 'reuse-id',
        instanceRevision: 1,
        points: const <Offset>[Offset(0, 0), Offset(10, 0)],
        pointsRevision: 1,
        thickness: 2,
        color: const Color(0xFF000000),
      );
      final newNode = StrokeNodeSnapshot(
        id: 'reuse-id',
        instanceRevision: 2,
        points: const <Offset>[Offset(0, 0), Offset(0, 10)],
        pointsRevision: 1,
        thickness: 2,
        color: const Color(0xFF000000),
      );

      final oldPath = cache.getOrBuild(oldNode);
      final newPath = cache.getOrBuild(newNode);
      final newPathHit = cache.getOrBuild(newNode);

      expect(identical(oldPath, newPath), isFalse);
      expect(identical(newPath, newPathHit), isTrue);
      expect(cache.debugBuildCount, 2);
      expect(cache.debugHitCount, 1);
    },
  );

  test('v2 stroke cache evicts least-recent entry (LRU)', () {
    final cache = SceneStrokePathCache(maxEntries: 2);
    final a = StrokeNodeSnapshot(
      id: 'a',
      points: const <Offset>[Offset(0, 0), Offset(1, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final b = StrokeNodeSnapshot(
      id: 'b',
      points: const <Offset>[Offset(0, 0), Offset(0, 1)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final c = StrokeNodeSnapshot(
      id: 'c',
      points: const <Offset>[Offset(1, 1), Offset(2, 2)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    cache.getOrBuild(a);
    cache.getOrBuild(b);
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 0);

    cache.getOrBuild(a);
    expect(cache.debugHitCount, 1);

    cache.getOrBuild(c);
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 1);
  });

  test('v2 stroke cache clear drops entries', () {
    final cache = SceneStrokePathCache(maxEntries: 8);
    final stroke = StrokeNodeSnapshot(
      id: 'clear',
      points: const <Offset>[Offset(0, 0), Offset(10, 10)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    cache.getOrBuild(stroke);
    expect(cache.debugSize, 1);
    cache.clear();
    expect(cache.debugSize, 0);
  });
}
