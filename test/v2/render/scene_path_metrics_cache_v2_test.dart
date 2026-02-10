import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/v2/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/v2/render/scene_painter_v2.dart';

void main() {
  test('ScenePathMetricsCacheV2 caches contours per id+path+fillRule', () {
    final cache = ScenePathMetricsCacheV2(maxEntries: 8);
    const node = PathNodeSnapshot(id: 'p-1', svgPathData: 'M0 0 H10 V10 H0 Z');
    final localPath = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));

    final entry1 = cache.getOrBuild(node: node, localPath: localPath);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 0);
    expect(cache.debugSize, 1);
    expect(entry1.closedContours, isNotNull);

    final entry2 = cache.getOrBuild(node: node, localPath: localPath);
    expect(identical(entry1, entry2), isTrue);
    expect(cache.debugBuildCount, 1);
    expect(cache.debugHitCount, 1);
    expect(cache.debugSize, 1);
  });

  test('ScenePathMetricsCacheV2 rebuilds on svgPathData change', () {
    final cache = ScenePathMetricsCacheV2(maxEntries: 8);
    const nodeA = PathNodeSnapshot(id: 'p-1', svgPathData: 'M0 0 H10 V10 H0 Z');
    final pathA = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
    final entry1 = cache.getOrBuild(node: nodeA, localPath: pathA);
    expect(cache.debugBuildCount, 1);

    const nodeB = PathNodeSnapshot(id: 'p-1', svgPathData: 'M0 0 H20 V10 H0 Z');
    final pathB = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 10));
    final entry2 = cache.getOrBuild(node: nodeB, localPath: pathB);
    expect(identical(entry1, entry2), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('ScenePathMetricsCacheV2 rebuilds on fillRule change', () {
    final cache = ScenePathMetricsCacheV2(maxEntries: 8);
    const nodeA = PathNodeSnapshot(id: 'p-1', svgPathData: 'M0 0 H10 V10 H0 Z');
    final pathA = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
    final entry1 = cache.getOrBuild(node: nodeA, localPath: pathA);
    expect(cache.debugBuildCount, 1);

    const nodeB = PathNodeSnapshot(
      id: 'p-1',
      svgPathData: 'M0 0 H10 V10 H0 Z',
      fillRule: V2PathFillRule.evenOdd,
    );
    final pathB = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
    final entry2 = cache.getOrBuild(node: nodeB, localPath: pathB);
    expect(identical(entry1, entry2), isFalse);
    expect(cache.debugBuildCount, 2);
  });

  test('ScenePathMetricsCacheV2 supports open-only and empty paths', () {
    final cache = ScenePathMetricsCacheV2(maxEntries: 8);
    const openNode = PathNodeSnapshot(id: 'open', svgPathData: 'M0 0 H10');
    final openPath = Path()
      ..moveTo(0, 0)
      ..lineTo(10, 0);

    final openEntry = cache.getOrBuild(node: openNode, localPath: openPath);
    expect(openEntry.closedContours, isNull);
    expect(openEntry.openContours, isNotEmpty);

    const emptyNode = PathNodeSnapshot(id: 'empty', svgPathData: 'M0 0 H10');
    final emptyEntry = cache.getOrBuild(node: emptyNode, localPath: Path());
    expect(emptyEntry.closedContours, isNull);
    expect(emptyEntry.openContours, isEmpty);
  });

  test('ScenePathMetricsCacheV2 evicts least-recent entry (LRU)', () {
    final cache = ScenePathMetricsCacheV2(maxEntries: 2);
    const a = PathNodeSnapshot(id: 'a', svgPathData: 'M0 0 H10');
    const b = PathNodeSnapshot(id: 'b', svgPathData: 'M0 0 V10');
    const c = PathNodeSnapshot(id: 'c', svgPathData: 'M0 0 H5 V5 H0 Z');

    cache.getOrBuild(
      node: a,
      localPath: Path()
        ..moveTo(0, 0)
        ..lineTo(10, 0),
    );
    cache.getOrBuild(
      node: b,
      localPath: Path()
        ..moveTo(0, 0)
        ..lineTo(0, 10),
    );
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 0);

    cache.getOrBuild(
      node: a,
      localPath: Path()
        ..moveTo(0, 0)
        ..lineTo(10, 0),
    );
    expect(cache.debugHitCount, 1);

    cache.getOrBuild(
      node: c,
      localPath: Path()..addRect(const Rect.fromLTWH(0, 0, 5, 5)),
    );
    expect(cache.debugSize, 2);
    expect(cache.debugEvictCount, 1);

    cache.getOrBuild(
      node: b,
      localPath: Path()
        ..moveTo(0, 0)
        ..lineTo(0, 10),
    );
    expect(cache.debugBuildCount, 4);
  });

  test('ScenePathMetricsCacheV2 clear drops entries', () {
    final cache = ScenePathMetricsCacheV2(maxEntries: 8);
    const node = PathNodeSnapshot(
      id: 'clear',
      svgPathData: 'M0 0 H10 V10 H0 Z',
    );

    cache.getOrBuild(
      node: node,
      localPath: Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
    );
    expect(cache.debugSize, 1);
    cache.clear();
    expect(cache.debugSize, 0);
  });
}
