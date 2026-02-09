import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/v2/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/v2/render/scene_painter_v2.dart';

void main() {
  test('v2 stroke cache handles empty/dot geometries safely', () {
    final cache = SceneStrokePathCacheV2(maxEntries: 8);
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

  test('v2 stroke cache rebuilds only when geometry changes', () {
    final cache = SceneStrokePathCacheV2(maxEntries: 8);
    final strokeA = StrokeNodeSnapshot(
      id: 's1',
      points: const <Offset>[Offset(0, 0), Offset(10, 10)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final strokeA2 = StrokeNodeSnapshot(
      id: 's1',
      points: const <Offset>[Offset(0, 0), Offset(10, 10)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final strokeChanged = StrokeNodeSnapshot(
      id: 's1',
      points: const <Offset>[Offset(0, 0), Offset(12, 10)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final first = cache.getOrBuild(strokeA);
    final second = cache.getOrBuild(strokeA2);
    final third = cache.getOrBuild(strokeChanged);

    expect(identical(first, second), isTrue);
    expect(identical(second, third), isFalse);
    expect(cache.debugBuildCount, 2);
    expect(cache.debugHitCount, 1);
  });
}
