import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/text_layout.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_path_metrics_cache.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_static_layer_cache.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_stroke_path_cache.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_text_layout_cache.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
import 'package:iwb_canvas_engine/src/render/scene_grid_renderer.dart';
import 'package:iwb_canvas_engine/src/render/scene_render_caches.dart';

void main() {
  // INV:INV-ENG-RENDER-CACHE-SCAN-RESISTANT
  test(
    'SceneRenderCaches clearAll forces rebuilds without changing local cache keys',
    () {
      // INV:INV-ENG-EPOCH-INVALIDATION
      // INV:INV-ENG-PERFORMANCE-PROOF-CONTOUR
      final staticCache = SceneStaticLayerCache();
      final textCache = SceneTextLayoutCache(maxEntries: 8);
      final strokeCache = SceneStrokePathCache(maxEntries: 8);
      final pathCache = ScenePathMetricsCache(maxEntries: 8);
      final geometryCache = RenderGeometryCache(maxEntries: 8);
      final renderCaches = SceneRenderCaches(
        staticLayerCache: staticCache,
        textLayoutCache: textCache,
        strokePathCache: strokeCache,
        pathMetricsCache: pathCache,
        geometryCache: geometryCache,
      );
      final textNode = _textNode();
      final strokeNode = _strokeNode();
      final pathNode = _pathNode();
      final localPath = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));

      final textBefore = textCache.getOrBuild(node: textNode);
      final strokeBefore = strokeCache.getOrBuild(strokeNode);
      final pathBefore = pathCache.getOrBuild(
        node: pathNode,
        localPath: localPath,
      );
      final geometryBefore = geometryCache.get(
        textNode,
        resolvedTextLayout: _resolvedTextLayout(textNode),
      );
      _primeStaticLayerCache(staticCache);

      renderCaches.clearAll();

      expect(textCache.debugSize, 0);
      expect(strokeCache.debugSize, 0);
      expect(pathCache.debugSize, 0);
      expect(geometryCache.debugSize, 0);
      expect(staticCache.debugKeyHashCode, isNull);
      expect(staticCache.debugDisposeCount, 1);

      final textAfter = textCache.getOrBuild(node: textNode);
      final strokeAfter = strokeCache.getOrBuild(strokeNode);
      final pathAfter = pathCache.getOrBuild(
        node: pathNode,
        localPath: localPath,
      );
      final geometryAfter = geometryCache.get(
        textNode,
        resolvedTextLayout: _resolvedTextLayout(textNode),
      );
      _primeStaticLayerCache(staticCache);

      expect(identical(textBefore, textAfter), isFalse);
      expect(identical(strokeBefore, strokeAfter), isFalse);
      expect(identical(pathBefore, pathAfter), isFalse);
      expect(identical(geometryBefore, geometryAfter), isFalse);
      expect(textCache.debugBuildCount, 2);
      expect(textCache.debugHitCount, 0);
      expect(strokeCache.debugBuildCount, 2);
      expect(strokeCache.debugHitCount, 0);
      expect(pathCache.debugBuildCount, 2);
      expect(pathCache.debugHitCount, 0);
      expect(geometryCache.debugBuildCount, 2);
      expect(geometryCache.debugHitCount, 0);
      expect(staticCache.debugBuildCount, 2);
    },
  );

  test('Scene text and stroke caches expose owner-level probe counters', () {
    final textCache = SceneTextLayoutCache(maxEntries: 1);
    final strokeCache = SceneStrokePathCache(maxEntries: 1);
    final textNode = _textNode();
    final otherTextNode = TextNodeSnapshot(
      id: 'text-2',
      text: 'other',
      fontSize: 14,
      color: const Color(0xFF000000),
      textDirection: TextDirection.ltr,
      maxWidth: 80,
    );
    final strokeNode = _strokeNode();
    final otherStrokeNode = StrokeNodeSnapshot(
      id: 'stroke-2',
      instanceRevision: 2,
      points: const <Offset>[Offset(0, 0), Offset(8, 4)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    textCache.getOrBuild(node: textNode);
    textCache.getOrBuild(node: textNode);
    textCache.getOrBuild(node: otherTextNode);

    strokeCache.getOrBuild(strokeNode);
    strokeCache.getOrBuild(strokeNode);
    strokeCache.getOrBuild(otherStrokeNode);

    expect(textCache.captureProbe(), (
      buildCount: 2,
      hitCount: 1,
      evictCount: 1,
    ));
    expect(strokeCache.captureProbe(), (
      buildCount: 2,
      hitCount: 1,
      evictCount: 1,
    ));
  });

  test(
    'SceneRenderCaches keeps steady-state cache reuse for stable ordered work over capacity',
    () {
      final textCache = SceneTextLayoutCache(maxEntries: 2);
      final strokeCache = SceneStrokePathCache(maxEntries: 2);
      final pathCache = ScenePathMetricsCache(maxEntries: 2);
      final geometryCache = RenderGeometryCache(maxEntries: 2);
      final renderCaches = SceneRenderCaches(
        textLayoutCache: textCache,
        strokePathCache: strokeCache,
        pathMetricsCache: pathCache,
        geometryCache: geometryCache,
      );
      final textNodes = <TextNodeSnapshot>[
        _textNode(id: 'text-a', text: 'A'),
        _textNode(id: 'text-b', text: 'B'),
        _textNode(id: 'text-c', text: 'C'),
      ];

      for (final node in textNodes) {
        renderCaches.textLayoutCache.getOrBuild(node: node);
        renderCaches.geometryCache.get(
          node,
          resolvedTextLayout: _resolvedTextLayout(node),
        );
      }
      final textBuildsAfterWarmup = textCache.debugBuildCount;
      final geometryBuildsAfterTextWarmup = geometryCache.debugBuildCount;

      for (final node in textNodes) {
        renderCaches.textLayoutCache.getOrBuild(node: node);
        renderCaches.geometryCache.get(
          node,
          resolvedTextLayout: _resolvedTextLayout(node),
        );
      }

      expect(textCache.debugBuildCount, lessThan(textBuildsAfterWarmup + 3));
      expect(textCache.debugHitCount, greaterThan(0));
      expect(
        geometryCache.debugBuildCount,
        lessThan(geometryBuildsAfterTextWarmup + 3),
      );
      expect(geometryCache.debugHitCount, greaterThan(0));

      renderCaches.clearAll();

      final strokeNodes = <StrokeNodeSnapshot>[
        _strokeNode(
          id: 'stroke-a',
          points: const <Offset>[Offset(0, 0), Offset(1, 0)],
        ),
        _strokeNode(
          id: 'stroke-b',
          points: const <Offset>[Offset(0, 0), Offset(0, 1)],
        ),
        _strokeNode(
          id: 'stroke-c',
          points: const <Offset>[Offset(1, 1), Offset(2, 2)],
        ),
      ];

      for (final node in strokeNodes) {
        renderCaches.strokePathCache.getOrBuild(node);
        renderCaches.geometryCache.get(node);
      }
      final strokeBuildsAfterWarmup = strokeCache.debugBuildCount;
      final geometryBuildsAfterStrokeWarmup = geometryCache.debugBuildCount;

      for (final node in strokeNodes) {
        renderCaches.strokePathCache.getOrBuild(node);
        renderCaches.geometryCache.get(node);
      }

      expect(
        strokeCache.debugBuildCount,
        lessThan(strokeBuildsAfterWarmup + 3),
      );
      expect(strokeCache.debugHitCount, greaterThan(0));
      expect(
        geometryCache.debugBuildCount,
        lessThan(geometryBuildsAfterStrokeWarmup + 3),
      );
      expect(geometryCache.debugHitCount, greaterThan(1));

      renderCaches.clearAll();

      final pathNodes = <PathNodeSnapshot>[
        _pathNode(id: 'path-a', svgPathData: 'M0 0 H10'),
        _pathNode(id: 'path-b', svgPathData: 'M0 0 V10'),
        _pathNode(id: 'path-c', svgPathData: 'M0 0 H5 V5 H0 Z'),
      ];
      final localPaths = <Path>[
        Path()
          ..moveTo(0, 0)
          ..lineTo(10, 0),
        Path()
          ..moveTo(0, 0)
          ..lineTo(0, 10),
        Path()..addRect(const Rect.fromLTWH(0, 0, 5, 5)),
      ];

      for (var i = 0; i < pathNodes.length; i++) {
        renderCaches.pathMetricsCache.getOrBuild(
          node: pathNodes[i],
          localPath: localPaths[i],
        );
        renderCaches.geometryCache.get(pathNodes[i]);
      }
      final pathBuildsAfterWarmup = pathCache.debugBuildCount;
      final geometryBuildsAfterPathWarmup = geometryCache.debugBuildCount;

      for (var i = 0; i < pathNodes.length; i++) {
        renderCaches.pathMetricsCache.getOrBuild(
          node: pathNodes[i],
          localPath: localPaths[i],
        );
        renderCaches.geometryCache.get(pathNodes[i]);
      }

      expect(pathCache.debugBuildCount, lessThan(pathBuildsAfterWarmup + 3));
      expect(pathCache.debugHitCount, greaterThan(0));
      expect(
        geometryCache.debugBuildCount,
        lessThan(geometryBuildsAfterPathWarmup + 3),
      );
      expect(geometryCache.debugHitCount, greaterThanOrEqualTo(3));
    },
  );

  test('SceneRenderCaches disposeOwned clears and disposes owned caches', () {
    final renderCaches = SceneRenderCaches();
    final textNode = _textNode();
    final strokeNode = _strokeNode();
    final pathNode = _pathNode();

    renderCaches.textLayoutCache.getOrBuild(node: textNode);
    renderCaches.strokePathCache.getOrBuild(strokeNode);
    renderCaches.pathMetricsCache.getOrBuild(
      node: pathNode,
      localPath: Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
    );
    renderCaches.geometryCache.get(
      textNode,
      resolvedTextLayout: _resolvedTextLayout(textNode),
    );
    _primeStaticLayerCache(renderCaches.staticLayerCache);

    renderCaches.disposeOwned();

    expect(renderCaches.textLayoutCache.debugSize, 0);
    expect(renderCaches.strokePathCache.debugSize, 0);
    expect(renderCaches.pathMetricsCache.debugSize, 0);
    expect(renderCaches.geometryCache.debugSize, 0);
    expect(renderCaches.staticLayerCache.debugKeyHashCode, isNull);
    expect(renderCaches.staticLayerCache.debugDisposeCount, 1);
  });

  test('SceneRenderCaches disposeOwned leaves external caches untouched', () {
    final staticCache = SceneStaticLayerCache();
    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final strokeCache = SceneStrokePathCache(maxEntries: 8);
    final pathCache = ScenePathMetricsCache(maxEntries: 8);
    final geometryCache = RenderGeometryCache(maxEntries: 8);
    final renderCaches = SceneRenderCaches(
      staticLayerCache: staticCache,
      textLayoutCache: textCache,
      strokePathCache: strokeCache,
      pathMetricsCache: pathCache,
      geometryCache: geometryCache,
    );
    final textNode = _textNode();
    final strokeNode = _strokeNode();
    final pathNode = _pathNode();
    final localPath = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));

    final textBefore = textCache.getOrBuild(node: textNode);
    final strokeBefore = strokeCache.getOrBuild(strokeNode);
    final pathBefore = pathCache.getOrBuild(
      node: pathNode,
      localPath: localPath,
    );
    final geometryBefore = geometryCache.get(
      textNode,
      resolvedTextLayout: _resolvedTextLayout(textNode),
    );
    _primeStaticLayerCache(staticCache);

    renderCaches.disposeOwned();

    expect(textCache.debugSize, 1);
    expect(strokeCache.debugSize, 1);
    expect(pathCache.debugSize, 1);
    expect(geometryCache.debugSize, 1);
    expect(staticCache.debugKeyHashCode, isNotNull);
    expect(staticCache.debugDisposeCount, 0);

    expect(identical(textBefore, textCache.getOrBuild(node: textNode)), isTrue);
    expect(identical(strokeBefore, strokeCache.getOrBuild(strokeNode)), isTrue);
    expect(
      identical(
        pathBefore,
        pathCache.getOrBuild(node: pathNode, localPath: localPath),
      ),
      isTrue,
    );
    expect(
      identical(
        geometryBefore,
        geometryCache.get(
          textNode,
          resolvedTextLayout: _resolvedTextLayout(textNode),
        ),
      ),
      isTrue,
    );
    expect(textCache.debugHitCount, 1);
    expect(strokeCache.debugHitCount, 1);
    expect(pathCache.debugHitCount, 1);
    expect(geometryCache.debugHitCount, 1);
  });

  test('SceneViewRenderCacheLifecycle clears caches on epoch change', () {
    final lifecycle = SceneViewRenderCacheLifecycle(
      create: () => SceneRenderCaches(
        staticLayerCache: SceneStaticLayerCache(),
        textLayoutCache: SceneTextLayoutCache(maxEntries: 8),
        strokePathCache: SceneStrokePathCache(maxEntries: 8),
        pathMetricsCache: ScenePathMetricsCache(maxEntries: 8),
        geometryCache: RenderGeometryCache(maxEntries: 8),
      ),
    );
    lifecycle.initialize(controllerEpoch: 1);
    final debugCaches = lifecycle.debugCaches;
    final localPath = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));

    debugCaches.textLayoutCache.getOrBuild(node: _textNode());
    debugCaches.strokePathCache.getOrBuild(_strokeNode());
    debugCaches.pathMetricsCache.getOrBuild(
      node: _pathNode(),
      localPath: localPath,
    );
    final textNode = _textNode();
    debugCaches.geometryCache.get(
      textNode,
      resolvedTextLayout: _resolvedTextLayout(textNode),
    );
    _primeStaticLayerCache(debugCaches.staticLayerCache);

    expect(lifecycle.clearIfEpochChanged(1), isFalse);
    expect(lifecycle.clearIfEpochChanged(2), isTrue);
    expect(debugCaches.textLayoutCache.debugSize, 0);
    expect(debugCaches.strokePathCache.debugSize, 0);
    expect(debugCaches.pathMetricsCache.debugSize, 0);
    expect(debugCaches.geometryCache.debugSize, 0);
    expect(debugCaches.staticLayerCache.debugKeyHashCode, isNull);
  });

  test(
    'SceneViewRenderCacheLifecycle recreates caches and disposes only owned ones',
    () {
      final externalGeometryCache = RenderGeometryCache(maxEntries: 8);
      final externalStaticCache = SceneStaticLayerCache();
      var createCount = 0;
      final lifecycle = SceneViewRenderCacheLifecycle(
        create: () {
          createCount += 1;
          return SceneRenderCaches(
            staticLayerCache: createCount == 1 ? null : externalStaticCache,
            textLayoutCache: SceneTextLayoutCache(maxEntries: 8),
            strokePathCache: SceneStrokePathCache(maxEntries: 8),
            pathMetricsCache: ScenePathMetricsCache(maxEntries: 8),
            geometryCache: createCount == 1 ? null : externalGeometryCache,
          );
        },
      );

      lifecycle.initialize(controllerEpoch: 1);
      final firstCaches = lifecycle.debugCaches;
      final textNode = _textNode();
      firstCaches.geometryCache.get(
        textNode,
        resolvedTextLayout: _resolvedTextLayout(textNode),
      );
      _primeStaticLayerCache(firstCaches.staticLayerCache);

      lifecycle.recreateCaches();

      final secondCaches = lifecycle.debugCaches;
      expect(createCount, 2);
      expect(firstCaches.geometryCache.debugSize, 0);
      expect(firstCaches.staticLayerCache.debugDisposeCount, 1);
      expect(secondCaches.geometryCache, same(externalGeometryCache));
      expect(secondCaches.staticLayerCache, same(externalStaticCache));

      final recreatedTextNode = _textNode();
      secondCaches.geometryCache.get(
        recreatedTextNode,
        resolvedTextLayout: _resolvedTextLayout(recreatedTextNode),
      );
      _primeStaticLayerCache(secondCaches.staticLayerCache);
      lifecycle.dispose();

      expect(externalGeometryCache.debugSize, 1);
      expect(externalStaticCache.debugDisposeCount, 0);
    },
  );
}

TextNodeSnapshot _textNode({String id = 'text', String text = 'cache'}) {
  return TextNodeSnapshot(
    id: id,
    text: text,
    fontSize: 14,
    color: const Color(0xFF000000),
    textDirection: TextDirection.ltr,
    maxWidth: 80,
  );
}

ResolvedTextLayout _resolvedTextLayout(TextNodeSnapshot node) {
  return TextLayoutRequest.forRenderSnapshot(node).resolve();
}

StrokeNodeSnapshot _strokeNode({
  String id = 'stroke',
  List<Offset> points = const <Offset>[Offset(0, 0), Offset(10, 10)],
}) {
  return StrokeNodeSnapshot(
    id: id,
    instanceRevision: 1,
    points: points,
    thickness: 2,
    color: const Color(0xFF000000),
  );
}

PathNodeSnapshot _pathNode({
  String id = 'path',
  String svgPathData = 'M0 0 H10 V10 H0 Z',
}) {
  return PathNodeSnapshot(
    id: id,
    instanceRevision: 1,
    svgPathData: svgPathData,
  );
}

void _primeStaticLayerCache(SceneStaticLayerCache cache) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  cache.draw(
    canvas,
    SceneGridRenderRequest(
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 10,
        color: Color(0xFF000000),
      ),
      size: Size(40, 40),
      cameraOffset: Offset(4, 6),
      gridStrokeWidth: 1,
    ),
    backgroundColor: const Color(0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  picture.dispose();
}
