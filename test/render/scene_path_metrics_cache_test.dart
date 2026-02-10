import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';

void main() {
  test('P1-1: ScenePathMetricsCache caches contours per id+path+fillRule', () {
    final cache = ScenePathMetricsCache(maxEntries: 8);
    final node = PathNode(id: 'p-1', svgPathData: 'M0 0 H10 V10 H0 Z');
    final localPath = node.buildLocalPath(copy: false)!;

    final entry1 = cache.getOrBuild(node: node, localPath: localPath);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 0);
    expect(cache.debugSize, 1);

    final entry2 = cache.getOrBuild(node: node, localPath: localPath);
    expect(identical(entry1, entry2), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
    expect(cache.debugSize, 1);
  });

  test('P1-2: ScenePathMetricsCache rebuilds on svgPathData change', () {
    final cache = ScenePathMetricsCache(maxEntries: 8);
    final node = PathNode(id: 'p-1', svgPathData: 'M0 0 H10 V10 H0 Z');
    final path1 = node.buildLocalPath(copy: false)!;
    final entry1 = cache.getOrBuild(node: node, localPath: path1);
    expect(cache.debugBuildCount, 1);

    node.svgPathData = 'M0 0 H20 V10 H0 Z';
    final path2 = node.buildLocalPath(copy: false)!;
    final entry2 = cache.getOrBuild(node: node, localPath: path2);
    expect(identical(entry1, entry2), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('P1-3: ScenePathMetricsCache rebuilds on fillRule change', () {
    final cache = ScenePathMetricsCache(maxEntries: 8);
    final node = PathNode(id: 'p-1', svgPathData: 'M0 0 H10 V10 H0 Z');
    final path1 = node.buildLocalPath(copy: false)!;
    final entry1 = cache.getOrBuild(node: node, localPath: path1);
    expect(cache.debugBuildCount, 1);

    node.fillRule = PathFillRule.evenOdd;
    final path2 = node.buildLocalPath(copy: false)!;
    final entry2 = cache.getOrBuild(node: node, localPath: path2);
    expect(identical(entry1, entry2), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('P1-4: ScenePathMetricsCache evicts least-recent entry (LRU)', () {
    final cache = ScenePathMetricsCache(maxEntries: 2);
    final a = PathNode(id: 'a', svgPathData: 'M0 0 H10');
    final b = PathNode(id: 'b', svgPathData: 'M0 0 V10');
    final c = PathNode(id: 'c', svgPathData: 'M0 0 H5 V5 H0 Z');

    cache.getOrBuild(node: a, localPath: a.buildLocalPath(copy: false)!);
    cache.getOrBuild(node: b, localPath: b.buildLocalPath(copy: false)!);
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 0);

    cache.getOrBuild(node: a, localPath: a.buildLocalPath(copy: false)!);
    expect(cache.debugHitCount, 1);

    cache.getOrBuild(node: c, localPath: c.buildLocalPath(copy: false)!);
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 1);

    cache.getOrBuild(node: b, localPath: b.buildLocalPath(copy: false)!);
    expect(cache.debugBuildCount, 4);
  });

  test('P1-5: ScenePathMetricsCache handles empty-metrics paths', () {
    final cache = ScenePathMetricsCache(maxEntries: 8);
    final node = PathNode(id: 'p-empty', svgPathData: 'M0 0 H10');
    final emptyPath = Path();

    final entry1 = cache.getOrBuild(node: node, localPath: emptyPath);
    expect(entry1.isEmpty, isTrue);
    expect(cache.debugBuildCount, 1);

    final entry2 = cache.getOrBuild(node: node, localPath: emptyPath);
    expect(entry2.isEmpty, isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
  });
}
