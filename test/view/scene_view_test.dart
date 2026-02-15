import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/render_geometry_cache.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';
import 'package:iwb_canvas_engine/src/view/scene_view.dart';

SceneSnapshot _snapshot({required double strokeY, required String text}) {
  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
        nodes: <NodeSnapshot>[
          TextNodeSnapshot(
            id: 'txt',
            text: text,
            size: const Size(80, 24),
            color: const Color(0xFF000000),
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
        nodes: <NodeSnapshot>[
          for (var i = 0; i < pairCount; i++) ...<NodeSnapshot>[
            TextNodeSnapshot(
              id: '$prefix-text-$i',
              text: '$prefix-$i',
              size: const Size(80, 24),
              color: const Color(0xFF000000),
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

void main() {
  testWidgets('SceneViewV2 clears all render caches on epoch change', (
    tester,
  ) async {
    // INV:INV-V2-EPOCH-INVALIDATION
    final controller = SceneControllerV2(
      initialSnapshot: _snapshot(strokeY: 20, text: 'A'),
    );
    addTearDown(controller.dispose);

    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final strokeCache = SceneStrokePathCache(maxEntries: 8);
    final staticCache = SceneStaticLayerCache();
    final geometryCache = RenderGeometryCache(maxEntries: 8);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneViewV2(
            controller: controller,
            imageResolver: (_) => null,
            textLayoutCache: textCache,
            strokePathCache: strokeCache,
            staticLayerCache: staticCache,
            geometryCache: geometryCache,
          ),
        ),
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

  testWidgets('SceneViewV2 clears caches when controller is replaced', (
    tester,
  ) async {
    final controllerA = SceneControllerV2(
      initialSnapshot: _snapshot(strokeY: 16, text: 'A'),
    );
    final controllerB = SceneControllerV2(
      initialSnapshot: _snapshot(strokeY: 16, text: 'A'),
    );
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final strokeCache = SceneStrokePathCache(maxEntries: 8);
    final staticCache = SceneStaticLayerCache();
    final geometryCache = RenderGeometryCache(maxEntries: 8);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneViewV2(
            controller: controllerA,
            imageResolver: (_) => null,
            textLayoutCache: textCache,
            strokePathCache: strokeCache,
            staticLayerCache: staticCache,
            geometryCache: geometryCache,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(textCache.debugBuildCount, 1);
    expect(strokeCache.debugBuildCount, 1);
    expect(staticCache.debugBuildCount, 1);
    expect(geometryCache.debugBuildCount, 2);
    expect(geometryCache.debugHitCount, 0);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneViewV2(
            controller: controllerB,
            imageResolver: (_) => null,
            textLayoutCache: textCache,
            strokePathCache: strokeCache,
            staticLayerCache: staticCache,
            geometryCache: geometryCache,
          ),
        ),
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
    'SceneViewV2 syncs owned/external caches and exposes debug getters',
    (tester) async {
      final controller = SceneControllerV2(
        initialSnapshot: _snapshot(strokeY: 12, text: 'sync'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 80,
            height: 80,
            child: SceneViewV2(controller: controller),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(SceneViewV2)) as dynamic;
      expect(state.debugStaticLayerCache, isA<SceneStaticLayerCache>());
      expect(state.debugTextLayoutCache, isA<SceneTextLayoutCache>());
      expect(state.debugStrokePathCache, isA<SceneStrokePathCache>());
      expect(state.debugPathMetricsCache, isA<ScenePathMetricsCache>());
      expect(state.debugGeometryCache, isA<RenderGeometryCache>());

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final painter = customPaint.painter! as ScenePainter;
      expect(painter.imageResolver('missing'), isNull);

      final extStaticA = SceneStaticLayerCache();
      final extTextA = SceneTextLayoutCache(maxEntries: 4);
      final extStrokeA = SceneStrokePathCache(maxEntries: 4);
      final extPathA = ScenePathMetricsCache(maxEntries: 4);
      final extGeometryA = RenderGeometryCache(maxEntries: 4);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 80,
            height: 80,
            child: SceneViewV2(
              controller: controller,
              staticLayerCache: extStaticA,
              textLayoutCache: extTextA,
              strokePathCache: extStrokeA,
              pathMetricsCache: extPathA,
              geometryCache: extGeometryA,
            ),
          ),
        ),
      );
      await tester.pump();

      final extStaticB = SceneStaticLayerCache();
      final extTextB = SceneTextLayoutCache(maxEntries: 4);
      final extStrokeB = SceneStrokePathCache(maxEntries: 4);
      final extPathB = ScenePathMetricsCache(maxEntries: 4);
      final extGeometryB = RenderGeometryCache(maxEntries: 4);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 80,
            height: 80,
            child: SceneViewV2(
              controller: controller,
              staticLayerCache: extStaticB,
              textLayoutCache: extTextB,
              strokePathCache: extStrokeB,
              pathMetricsCache: extPathB,
              geometryCache: extGeometryB,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(extGeometryB.debugSize, greaterThan(0));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 80,
            height: 80,
            child: SceneViewV2(controller: controller),
          ),
        ),
      );
      await tester.pump();
      expect(extGeometryB.debugSize, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(extGeometryB.debugSize, greaterThan(0));
    },
  );

  testWidgets(
    'SceneViewV2 replaceScene clears stale cache tails after heavy churn',
    (tester) async {
      final controller = SceneControllerV2(
        initialSnapshot: _churnSnapshot(pairCount: 24, prefix: 'old'),
      );
      addTearDown(controller.dispose);

      final textCache = SceneTextLayoutCache(maxEntries: 256);
      final strokeCache = SceneStrokePathCache(maxEntries: 256);
      final pathMetricsCache = ScenePathMetricsCache(maxEntries: 256);
      final staticCache = SceneStaticLayerCache();
      final geometryCache = RenderGeometryCache(maxEntries: 256);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 96,
            height: 96,
            child: SceneViewV2(
              controller: controller,
              imageResolver: (_) => null,
              textLayoutCache: textCache,
              strokePathCache: strokeCache,
              pathMetricsCache: pathMetricsCache,
              staticLayerCache: staticCache,
              geometryCache: geometryCache,
            ),
          ),
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
