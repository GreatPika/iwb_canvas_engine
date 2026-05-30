import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/frame/frame_cache.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/paint_plan.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('render family caches are 1024 entry scan-resistant LRU caches', () {
    _expectTextLayoutLru();
    _expectPathGeometryLru();
    _expectStrokePathLru();
    expect(TextLayoutCache().capacity, 1024);
  });

  test('ordinary paint plan cache is 16 entry LRU with probes', () {
    final cache = PaintPlanCache();
    final first = _paintKey(0);
    final second = _paintKey(1);

    for (var index = 0; index < 16; index += 1) {
      final key = _paintKey(index);
      cache.write(key, PaintPlan(key: key, ordinaryRecords: const []));
    }
    expect(cache.probe.entries, 16);
    expect(cache.read(first), isNotNull);

    final extra = _paintKey(16);
    cache.write(extra, PaintPlan(key: extra, ordinaryRecords: const []));

    expect(cache.probe.entries, 16);
    expect(cache.probe.hits, 1);
    expect(cache.probe.evictions, 1);
    expect(cache.containsKey(first), isTrue);
    expect(cache.containsKey(second), isFalse);
    expect(cache.probe.writes, 17);
  });

  test('ordinary planning binds text, path, and stroke family caches', () {
    final frameFacts = frameFactsPort(
      elements: [
        textFacts('text-a', orderToken: 1),
        pathFacts('path-a', orderToken: 2),
        strokeFacts('stroke-a', orderToken: 3),
      ],
    );
    final planner = OrdinaryPaintPlanner();

    planner.buildOrdinaryPlan(capturedMainFrame(frameFacts: frameFacts));
    planner.buildOrdinaryPlan(
      capturedMainFrame(
        frameFacts: frameFacts,
        viewport: const Rect.fromLTWH(100, 0, 10, 10),
      ),
    );

    expect(planner.textLayoutCache.probe.entries, 1);
    expect(planner.textLayoutCache.probe.misses, 1);
    expect(planner.textLayoutCache.probe.hits, 1);
    expect(planner.pathGeometryCache.probe.entries, 1);
    expect(planner.pathGeometryCache.probe.misses, 1);
    expect(planner.pathGeometryCache.probe.hits, 1);
    expect(planner.strokePathCache.probe.entries, 1);
    expect(planner.strokePathCache.probe.misses, 1);
    expect(planner.strokePathCache.probe.hits, 1);
  });

  test('stroke cache keys include full transform scale matrix', () {
    final frameFacts = frameFactsPort(
      elements: [
        strokeFacts('stroke-a', orderToken: 1),
        strokeFacts(
          'stroke-b',
          orderToken: 2,
          transform: CanvasTransform.rotationDegrees(90),
        ),
      ],
    );
    final planner = OrdinaryPaintPlanner();

    planner.buildOrdinaryPlan(capturedMainFrame(frameFacts: frameFacts));

    expect(planner.strokePathCache.probe.entries, 2);
    expect(planner.strokePathCache.probe.misses, 2);
  });
}

void _expectTextLayoutLru() {
  final cache = TextLayoutCache();
  final first = _textKey(0);
  final second = _textKey(1);

  for (var index = 0; index < 1024; index += 1) {
    cache.write(_textKey(index), TextLayoutCacheEntry(debugLabel: '$index'));
  }
  expect(cache.read(first), isNotNull);
  for (var index = 1024; index < 2048; index += 1) {
    cache.write(_textKey(index), TextLayoutCacheEntry(debugLabel: '$index'));
  }

  expect(cache.capacity, 1024);
  expect(cache.probe.entries, 1024);
  expect(cache.probe.hits, 1);
  expect(cache.probe.evictions, 1024);
  expect(cache.protectedEntryCount, 1);
  expect(cache.probationaryEntryCount, 1023);
  expect(cache.containsKey(first), isTrue);
  expect(cache.containsKey(second), isFalse);
}

void _expectPathGeometryLru() {
  final cache = PathGeometryCache();
  final first = _pathKey(0);
  final second = _pathKey(1);

  for (var index = 0; index < 1024; index += 1) {
    cache.write(_pathKey(index), PathGeometryCacheEntry(debugLabel: '$index'));
  }
  expect(cache.read(first), isNotNull);
  for (var index = 1024; index < 2048; index += 1) {
    cache.write(_pathKey(index), PathGeometryCacheEntry(debugLabel: '$index'));
  }

  expect(cache.capacity, 1024);
  expect(cache.probe.entries, 1024);
  expect(cache.probe.hits, 1);
  expect(cache.probe.evictions, 1024);
  expect(cache.protectedEntryCount, 1);
  expect(cache.probationaryEntryCount, 1023);
  expect(cache.containsKey(first), isTrue);
  expect(cache.containsKey(second), isFalse);
}

void _expectStrokePathLru() {
  final cache = StrokePathCache();
  final first = _strokeKey(0);
  final second = _strokeKey(1);

  for (var index = 0; index < 1024; index += 1) {
    cache.write(_strokeKey(index), StrokePathCacheEntry(debugLabel: '$index'));
  }
  expect(cache.read(first), isNotNull);
  for (var index = 1024; index < 2048; index += 1) {
    cache.write(_strokeKey(index), StrokePathCacheEntry(debugLabel: '$index'));
  }

  expect(cache.capacity, 1024);
  expect(cache.probe.entries, 1024);
  expect(cache.probe.hits, 1);
  expect(cache.probe.evictions, 1024);
  expect(cache.protectedEntryCount, 1);
  expect(cache.probationaryEntryCount, 1023);
  expect(cache.containsKey(first), isTrue);
  expect(cache.containsKey(second), isFalse);
}

TextLayoutCacheKey _textKey(int index) {
  return TextLayoutCacheKey(
    text: 'text-$index',
    fontSize: 12,
    colorValue: 0,
    alignName: 'left',
    directionName: 'ltr',
    isBold: false,
    isItalic: false,
    isUnderline: false,
    fontFamily: null,
    maxWidth: null,
    lineHeight: null,
  );
}

PathGeometryCacheKey _pathKey(int index) {
  return PathGeometryCacheKey(
    pathData: 'M0,0 L$index,$index',
    fillRuleName: 'nonZero',
    strokeWidth: 1,
  );
}

StrokePathCacheKey _strokeKey(int index) {
  return StrokePathCacheKey(
    pointsKey: '0,0;$index,$index',
    thickness: 1,
    transformScaleKey: '1x1',
  );
}

PaintPlanKey _paintKey(int index) {
  return PaintPlanKey(
    structuralRevision: index,
    boundsRevision: 1,
    elementVisualRevision: 1,
    viewportRect: Rect.fromLTWH(index.toDouble(), 0, 10, 10),
    devicePixelRatio: 1,
  );
}
