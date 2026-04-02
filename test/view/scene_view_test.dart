import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';
import 'package:iwb_canvas_engine/src/view/scene_view_render_surface.dart';

SceneSnapshot _snapshot({required double strokeY, required String text}) {
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-0',
        nodes: <NodeSnapshot>[
          TextNodeSnapshot(
            id: 'txt',
            text: text,
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
          ),
          StrokeNodeSnapshot(
            id: 'stroke',
            points: <Offset>[Offset(8, strokeY), Offset(72, strokeY)],
            pointsRevision: strokeY.abs().round(),
            thickness: 3,
            color: const Color(0xFF000000),
          ),
        ],
      ),
    ],
    background: const BackgroundSnapshot(
      grid: GridSnapshot(isEnabled: true, cellSize: 12),
    ),
  );
}

SceneSnapshot _churnSnapshot({required int pairCount, required String prefix}) {
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        id: 'layer-auto-1',
        nodes: <NodeSnapshot>[
          for (var i = 0; i < pairCount; i++) ...<NodeSnapshot>[
            TextNodeSnapshot(
              id: '$prefix-text-$i',
              text: '$prefix-$i',
              color: const Color(0xFF000000),
              textDirection: TextDirection.ltr,
            ),
            StrokeNodeSnapshot(
              id: '$prefix-stroke-$i',
              points: <Offset>[Offset(8, i * 4), Offset(72, i * 4)],
              pointsRevision: i,
              thickness: 3,
              color: const Color(0xFF000000),
            ),
          ],
        ],
      ),
    ],
  );
}

Widget _coreHost(
  SceneStoreController controller, {
  ui.Image? Function(String imageId)? imageResolver,
  SceneStaticLayerCache? staticLayerCache,
  SceneTextLayoutCache? textLayoutCache,
  SceneStrokePathCache? strokePathCache,
  ScenePathMetricsCache? pathMetricsCache,
  RenderGeometryCache? geometryCache,
  double width = 80,
  double height = 80,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: width,
      height: height,
      child: SceneViewRenderSurface.store(
        controller: controller,
        imageResolver: imageResolver,
        staticLayerCache: staticLayerCache,
        textLayoutCache: textLayoutCache,
        strokePathCache: strokePathCache,
        pathMetricsCache: pathMetricsCache,
        geometryCache: geometryCache,
      ),
    ),
  );
}

void main() {
  testWidgets('debugSceneViewRenderCachesOf supports descendant contexts', (
    tester,
  ) async {
    final controller = SceneStoreController(
      initialSnapshot: _snapshot(strokeY: 10, text: 'ctx'),
    );
    final staticLayerCache = SceneStaticLayerCache();
    final textLayoutCache = SceneTextLayoutCache();
    final strokePathCache = SceneStrokePathCache();
    final pathMetricsCache = ScenePathMetricsCache();
    final geometryCache = RenderGeometryCache();
    addTearDown(controller.dispose);
    addTearDown(staticLayerCache.dispose);

    await tester.pumpWidget(
      _coreHost(
        controller,
        imageResolver: (_) => null,
        staticLayerCache: staticLayerCache,
        textLayoutCache: textLayoutCache,
        strokePathCache: strokePathCache,
        pathMetricsCache: pathMetricsCache,
        geometryCache: geometryCache,
      ),
    );
    await tester.pump();

    final descendantContext = tester.element(find.byType(CustomPaint));
    final renderCaches = debugSceneViewRenderCachesOf(descendantContext);

    expect(renderCaches.staticLayerCache, same(staticLayerCache));
    expect(renderCaches.textLayoutCache, same(textLayoutCache));
    expect(renderCaches.strokePathCache, same(strokePathCache));
    expect(renderCaches.pathMetricsCache, same(pathMetricsCache));
    expect(renderCaches.geometryCache, same(geometryCache));
  });

  testWidgets(
    'debugSceneViewRenderCachesOf throws without SceneViewRenderSurface',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 40, height: 40),
        ),
      );

      expect(
        () =>
            debugSceneViewRenderCachesOf(tester.element(find.byType(SizedBox))),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No SceneViewRenderSurface state found for the provided BuildContext.',
          ),
        ),
      );
    },
  );

  testWidgets('core render surface clears all render caches on epoch change', (
    tester,
  ) async {
    // INV:INV-ENG-EPOCH-INVALIDATION
    final controller = SceneStoreController(
      initialSnapshot: _snapshot(strokeY: 20, text: 'A'),
    );
    addTearDown(controller.dispose);

    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final strokeCache = SceneStrokePathCache(maxEntries: 8);
    final staticCache = SceneStaticLayerCache();
    final geometryCache = RenderGeometryCache(maxEntries: 8);

    await tester.pumpWidget(
      _coreHost(
        controller,
        width: 96,
        height: 96,
        imageResolver: (_) => null,
        textLayoutCache: textCache,
        strokePathCache: strokeCache,
        staticLayerCache: staticCache,
        geometryCache: geometryCache,
      ),
    );
    await tester.pump();

    expect(textCache.debugBuildCount, 1);
    expect(strokeCache.debugBuildCount, 1);
    expect(staticCache.debugBuildCount, 1);
    expect(geometryCache.debugBuildCount, 2);
    expect(geometryCache.debugHitCount, 0);

    controller.writeReplaceScene(_snapshot(strokeY: 20, text: 'A'));
    await tester.pump();
    await tester.pump();

    expect(textCache.debugBuildCount, 2);
    expect(textCache.debugHitCount, 0);
    expect(strokeCache.debugBuildCount, 2);
    expect(strokeCache.debugHitCount, 0);
    expect(staticCache.debugBuildCount, 2);
    expect(geometryCache.debugBuildCount, 4);
    expect(geometryCache.debugHitCount, 0);
  });

  testWidgets('core render surface clears caches when controller is replaced', (
    tester,
  ) async {
    final controllerA = SceneStoreController(
      initialSnapshot: _snapshot(strokeY: 16, text: 'A'),
    );
    final controllerB = SceneStoreController(
      initialSnapshot: _snapshot(strokeY: 16, text: 'A'),
    );
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final strokeCache = SceneStrokePathCache(maxEntries: 8);
    final staticCache = SceneStaticLayerCache();
    final geometryCache = RenderGeometryCache(maxEntries: 8);

    await tester.pumpWidget(
      _coreHost(
        controllerA,
        width: 96,
        height: 96,
        imageResolver: (_) => null,
        textLayoutCache: textCache,
        strokePathCache: strokeCache,
        staticLayerCache: staticCache,
        geometryCache: geometryCache,
      ),
    );
    await tester.pump();
    expect(textCache.debugBuildCount, 1);
    expect(strokeCache.debugBuildCount, 1);
    expect(staticCache.debugBuildCount, 1);
    expect(geometryCache.debugBuildCount, 2);
    expect(geometryCache.debugHitCount, 0);

    await tester.pumpWidget(
      _coreHost(
        controllerB,
        width: 96,
        height: 96,
        imageResolver: (_) => null,
        textLayoutCache: textCache,
        strokePathCache: strokeCache,
        staticLayerCache: staticCache,
        geometryCache: geometryCache,
      ),
    );
    await tester.pump();

    expect(textCache.debugBuildCount, 2);
    expect(textCache.debugHitCount, 0);
    expect(strokeCache.debugBuildCount, 2);
    expect(strokeCache.debugHitCount, 0);
    expect(staticCache.debugBuildCount, 2);
    expect(geometryCache.debugBuildCount, 4);
    expect(geometryCache.debugHitCount, 0);
  });

  testWidgets(
    'core render surface syncs owned/external caches and exposes debug getters',
    (tester) async {
      final controller = SceneStoreController(
        initialSnapshot: _snapshot(strokeY: 12, text: 'sync'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_coreHost(controller));
      await tester.pump();

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final painter = customPaint.painter;
      if (painter == null) {
        fail('Expected ScenePainter.');
      }
      final renderCaches = debugSceneViewRenderCachesOf(
        tester.element(find.byType(SceneViewRenderSurface)),
      );
      final scenePainter = painter as ScenePainter;
      expect(scenePainter.staticLayerCache, isA<SceneStaticLayerCache>());
      expect(scenePainter.textLayoutCache, isA<SceneTextLayoutCache>());
      expect(scenePainter.strokePathCache, isA<SceneStrokePathCache>());
      expect(scenePainter.pathMetricsCache, isA<ScenePathMetricsCache>());
      expect(
        renderCaches.staticLayerCache,
        same(scenePainter.staticLayerCache),
      );
      expect(renderCaches.textLayoutCache, same(scenePainter.textLayoutCache));
      expect(renderCaches.strokePathCache, same(scenePainter.strokePathCache));
      expect(
        renderCaches.pathMetricsCache,
        same(scenePainter.pathMetricsCache),
      );
      expect(renderCaches.geometryCache, isA<RenderGeometryCache>());
      expect(scenePainter.imageResolver('missing'), isNull);

      final extStaticA = SceneStaticLayerCache();
      final extTextA = SceneTextLayoutCache(maxEntries: 4);
      final extStrokeA = SceneStrokePathCache(maxEntries: 4);
      final extPathA = ScenePathMetricsCache(maxEntries: 4);
      final extGeometryA = RenderGeometryCache(maxEntries: 4);

      await tester.pumpWidget(
        _coreHost(
          controller,
          staticLayerCache: extStaticA,
          textLayoutCache: extTextA,
          strokePathCache: extStrokeA,
          pathMetricsCache: extPathA,
          geometryCache: extGeometryA,
        ),
      );
      await tester.pump();

      final extStaticB = SceneStaticLayerCache();
      final extTextB = SceneTextLayoutCache(maxEntries: 4);
      final extStrokeB = SceneStrokePathCache(maxEntries: 4);
      final extPathB = ScenePathMetricsCache(maxEntries: 4);
      final extGeometryB = RenderGeometryCache(maxEntries: 4);

      await tester.pumpWidget(
        _coreHost(
          controller,
          staticLayerCache: extStaticB,
          textLayoutCache: extTextB,
          strokePathCache: extStrokeB,
          pathMetricsCache: extPathB,
          geometryCache: extGeometryB,
        ),
      );
      await tester.pump();
      final extRenderCaches = debugSceneViewRenderCachesOf(
        tester.element(find.byType(SceneViewRenderSurface)),
      );
      expect(extRenderCaches.staticLayerCache, same(extStaticB));
      expect(extRenderCaches.textLayoutCache, same(extTextB));
      expect(extRenderCaches.strokePathCache, same(extStrokeB));
      expect(extRenderCaches.pathMetricsCache, same(extPathB));
      expect(extRenderCaches.geometryCache, same(extGeometryB));
      expect(extRenderCaches.geometryCache, isNot(same(extGeometryA)));

      await tester.pumpWidget(_coreHost(controller));
      await tester.pump();
      final ownedRenderCaches = debugSceneViewRenderCachesOf(
        tester.element(find.byType(SceneViewRenderSurface)),
      );
      expect(ownedRenderCaches.geometryCache, isNot(same(extGeometryB)));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'core render surface replaceScene clears stale cache tails after heavy churn',
    (tester) async {
      final controller = SceneStoreController(
        initialSnapshot: _churnSnapshot(pairCount: 24, prefix: 'old'),
      );
      addTearDown(controller.dispose);

      final textCache = SceneTextLayoutCache(maxEntries: 256);
      final strokeCache = SceneStrokePathCache(maxEntries: 256);
      final pathMetricsCache = ScenePathMetricsCache(maxEntries: 256);
      final staticCache = SceneStaticLayerCache();
      final geometryCache = RenderGeometryCache(maxEntries: 256);

      await tester.pumpWidget(
        _coreHost(
          controller,
          width: 96,
          height: 96,
          imageResolver: (_) => null,
          textLayoutCache: textCache,
          strokePathCache: strokeCache,
          pathMetricsCache: pathMetricsCache,
          staticLayerCache: staticCache,
          geometryCache: geometryCache,
        ),
      );
      await tester.pump();

      expect(textCache.debugSize, 24);
      expect(strokeCache.debugSize, 24);
      expect(pathMetricsCache.debugSize, 0);
      expect(geometryCache.debugSize, 48);

      controller.writeReplaceScene(
        _churnSnapshot(pairCount: 2, prefix: 'fresh'),
      );
      await tester.pump();
      await tester.pump();

      expect(textCache.debugSize, 2);
      expect(strokeCache.debugSize, 2);
      expect(pathMetricsCache.debugSize, 0);
      expect(geometryCache.debugSize, 4);
      expect(
        controller.snapshot.layers.first.nodes.every(
          (node) => node.id.startsWith('fresh-'),
        ),
        isTrue,
      );
    },
  );
}
