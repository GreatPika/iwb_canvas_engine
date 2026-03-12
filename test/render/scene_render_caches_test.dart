import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_path_metrics_cache.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_static_layer_cache.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_stroke_path_cache.dart';
import 'package:iwb_canvas_engine/src/render/cache/scene_text_layout_cache.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
import 'package:iwb_canvas_engine/src/render/scene_render_caches.dart';

void main() {
  test(
    'SceneRenderCaches clearAll forces rebuilds without changing local cache keys',
    () {
      // INV:INV-ENG-EPOCH-INVALIDATION
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
      final geometryBefore = geometryCache.get(textNode);
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
      final geometryAfter = geometryCache.get(textNode);
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
    renderCaches.geometryCache.get(textNode);
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
    final geometryBefore = geometryCache.get(textNode);
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
    expect(identical(geometryBefore, geometryCache.get(textNode)), isTrue);
    expect(textCache.debugHitCount, 1);
    expect(strokeCache.debugHitCount, 1);
    expect(pathCache.debugHitCount, 1);
    expect(geometryCache.debugHitCount, 1);
  });
}

TextNodeSnapshot _textNode() {
  return TextNodeSnapshot(
    id: 'text',
    text: 'cache',
    size: const Size(80, 24),
    fontSize: 14,
    color: const Color(0xFF000000),
    maxWidth: 80,
  );
}

StrokeNodeSnapshot _strokeNode() {
  return StrokeNodeSnapshot(
    id: 'stroke',
    instanceRevision: 1,
    points: const <Offset>[Offset(0, 0), Offset(10, 10)],
    pointsRevision: 1,
    thickness: 2,
    color: const Color(0xFF000000),
  );
}

PathNodeSnapshot _pathNode() {
  return PathNodeSnapshot(
    id: 'path',
    instanceRevision: 1,
    svgPathData: 'M0 0 H10 V10 H0 Z',
  );
}

void _primeStaticLayerCache(SceneStaticLayerCache cache) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  cache.draw(
    canvas,
    const Size(40, 40),
    background: const BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 10,
        color: Color(0xFF000000),
      ),
    ),
    cameraOffset: const Offset(4, 6),
    gridStrokeWidth: 1,
  );
  final picture = recorder.endRecording();
  picture.dispose();
}
