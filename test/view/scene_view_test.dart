import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';
import 'package:iwb_canvas_engine/src/view/scene_view.dart';

SceneSnapshot _snapshot({required double strokeY, required String text}) {
  return SceneSnapshot(
    layers: <LayerSnapshot>[
      LayerSnapshot(
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

void main() {
  testWidgets('SceneViewV2 clears all render caches on epoch change', (
    tester,
  ) async {
    // INV:INV-V2-EPOCH-INVALIDATION
    final controller = SceneControllerV2(
      initialSnapshot: _snapshot(strokeY: 20, text: 'A'),
    );
    addTearDown(controller.dispose);

    final textCache = SceneTextLayoutCacheV2(maxEntries: 8);
    final strokeCache = SceneStrokePathCacheV2(maxEntries: 8);
    final staticCache = SceneStaticLayerCacheV2();

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
          ),
        ),
      ),
    );
    await tester.pump();

    expect(textCache.debugBuildCount, 1);
    expect(strokeCache.debugBuildCount, 1);
    expect(staticCache.debugBuildCount, 1);

    controller.writeReplaceScene(_snapshot(strokeY: 60, text: 'B'));
    await tester.pump();

    expect(textCache.debugBuildCount, 2);
    expect(textCache.debugHitCount, 0);
    expect(strokeCache.debugBuildCount, 2);
    expect(strokeCache.debugHitCount, 0);
    expect(staticCache.debugBuildCount, 2);
  });

  testWidgets('SceneViewV2 clears caches when controller is replaced', (
    tester,
  ) async {
    final controllerA = SceneControllerV2(
      initialSnapshot: _snapshot(strokeY: 16, text: 'A'),
    );
    final controllerB = SceneControllerV2(
      initialSnapshot: _snapshot(strokeY: 72, text: 'B'),
    );
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);

    final textCache = SceneTextLayoutCacheV2(maxEntries: 8);
    final strokeCache = SceneStrokePathCacheV2(maxEntries: 8);
    final staticCache = SceneStaticLayerCacheV2();

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
          ),
        ),
      ),
    );
    await tester.pump();
    expect(textCache.debugBuildCount, 1);
    expect(strokeCache.debugBuildCount, 1);
    expect(staticCache.debugBuildCount, 1);

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
      expect(state.debugStaticLayerCache, isA<SceneStaticLayerCacheV2>());
      expect(state.debugTextLayoutCache, isA<SceneTextLayoutCacheV2>());
      expect(state.debugStrokePathCache, isA<SceneStrokePathCacheV2>());
      expect(state.debugPathMetricsCache, isA<ScenePathMetricsCacheV2>());

      final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
      final painter = customPaint.painter! as ScenePainterV2;
      expect(painter.imageResolver('missing'), isNull);

      final extStaticA = SceneStaticLayerCacheV2();
      final extTextA = SceneTextLayoutCacheV2(maxEntries: 4);
      final extStrokeA = SceneStrokePathCacheV2(maxEntries: 4);
      final extPathA = ScenePathMetricsCacheV2(maxEntries: 4);

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
            ),
          ),
        ),
      );
      await tester.pump();

      final extStaticB = SceneStaticLayerCacheV2();
      final extTextB = SceneTextLayoutCacheV2(maxEntries: 4);
      final extStrokeB = SceneStrokePathCacheV2(maxEntries: 4);
      final extPathB = ScenePathMetricsCacheV2(maxEntries: 4);

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
            ),
          ),
        ),
      );
      await tester.pump();

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

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
