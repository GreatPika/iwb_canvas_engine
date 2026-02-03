import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SceneView builds without AnimatedBuilder and repaints via controller',
    (tester) async {
      final scene = Scene(layers: [Layer()]);
      final controller = SceneController(scene: scene);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 64,
            height: 64,
            child: SceneView(
              controller: controller,
              imageResolver: (_) => null,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedBuilder), findsNothing);

      final renderObject = tester.renderObject<rendering.RenderCustomPaint>(
        find.byType(CustomPaint),
      );
      final painter = renderObject.painter as ScenePainter;
      expect(painter.controller, same(controller));

      controller.addNode(
        RectNode(
          id: 'rect-1',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(8, 8),
      );

      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pump();

      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('SceneView creates internal controller when missing', (
    tester,
  ) async {
    SceneController? createdController;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            imageResolver: (_) => null,
            onControllerReady: (controller) {
              createdController = controller;
              controller.addNode(
                RectNode(
                  id: 'rect-1',
                  size: const Size(100, 80),
                  fillColor: const Color(0xFF2196F3),
                )..position = const Offset(150, 150),
              );
            },
          ),
        ),
      ),
    );

    expect(createdController, isNotNull);
    expect(createdController!.selectedNodeIds, isEmpty);

    await tester.tapAt(const Offset(150, 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(createdController!.selectedNodeIds, contains('rect-1'));
  });

  testWidgets('SceneView selects a node on tap', (tester) async {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            RectNode(
              id: 'rect-1',
              size: const Size(100, 80),
              fillColor: const Color(0xFF2196F3),
            )..position = const Offset(150, 150),
          ],
        ),
      ],
    );

    final controller = SceneController(scene: scene);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );

    expect(controller.selectedNodeIds, isEmpty);

    await tester.tapAt(const Offset(150, 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.selectedNodeIds, contains('rect-1'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('SceneView does not call onControllerReady for external', (
    tester,
  ) async {
    var called = false;
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            controller: controller,
            imageResolver: (_) => null,
            onControllerReady: (_) => called = true,
          ),
        ),
      ),
    );

    expect(called, isFalse);
  });

  testWidgets('SceneView switches from internal to external controller', (
    tester,
  ) async {
    SceneController? internalController;
    var readyCalls = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            imageResolver: (_) => null,
            onControllerReady: (controller) {
              readyCalls += 1;
              internalController = controller;
            },
          ),
        ),
      ),
    );

    expect(internalController, isNotNull);
    expect(readyCalls, 1);

    final externalController = SceneController(
      scene: Scene(
        layers: [
          Layer(
            nodes: [
              RectNode(
                id: 'rect-1',
                size: const Size(100, 80),
                fillColor: const Color(0xFF2196F3),
              )..position = const Offset(150, 150),
            ],
          ),
        ],
      ),
    );
    addTearDown(externalController.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            controller: externalController,
            imageResolver: (_) => null,
            onControllerReady: (_) => readyCalls += 1,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(150, 150));
    await tester.pump();

    expect(externalController.selectedNodeIds, contains('rect-1'));
    expect(readyCalls, 1);
  });

  testWidgets('SceneView switches from external to internal controller', (
    tester,
  ) async {
    final externalController = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(externalController.dispose);
    SceneController? internalController;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            controller: externalController,
            imageResolver: (_) => null,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            imageResolver: (_) => null,
            onControllerReady: (controller) {
              internalController = controller;
            },
          ),
        ),
      ),
    );

    expect(internalController, isNotNull);
  });

  testWidgets('SceneView dispatches double-tap signals', (tester) async {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            TextNode(
              id: 'text-1',
              text: 'Hello',
              size: const Size(200, 60),
              color: const Color(0xFF000000),
            )..position = const Offset(150, 150),
          ],
        ),
      ],
    );

    final controller = SceneController(
      scene: scene,
      pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 300),
    );
    addTearDown(controller.dispose);

    final requests = <EditTextRequested>[];
    controller.editTextRequests.listen(requests.add);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );

    await tester.tapAt(const Offset(150, 150));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tapAt(const Offset(150, 150));
    await tester.pump();

    expect(requests, hasLength(1));
    expect(requests.single.nodeId, 'text-1');
    expect(requests.single.position, const Offset(150, 150));
  });

  testWidgets('SceneView handles pointer cancel', (tester) async {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            RectNode(
              id: 'rect-1',
              size: const Size(100, 80),
              fillColor: const Color(0xFF2196F3),
            )..position = const Offset(150, 150),
          ],
        ),
      ],
    );

    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(140, 150));
    await gesture.moveTo(const Offset(170, 150));
    await gesture.cancel();
    await tester.pump();

    await tester.tapAt(const Offset(150, 150));
    await tester.pump();

    expect(controller.selectedNodeIds, contains('rect-1'));
  });

  testWidgets('SceneView rebuilds cleanly when controller changes', (
    tester,
  ) async {
    final controllerA = SceneController(
      scene: Scene(layers: [Layer()]),
      pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 20),
    );
    addTearDown(controllerA.dispose);

    final controllerB = SceneController(
      scene: Scene(layers: [Layer()]),
      pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 20),
    );
    addTearDown(controllerB.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(controller: controllerA, imageResolver: (_) => null),
        ),
      ),
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(controller: controllerB, imageResolver: (_) => null),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('SceneView rebuilds with the same controller instance', (
    tester,
  ) async {
    final controller = SceneController(
      scene: Scene(layers: [Layer()]),
      pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 20),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
  });

  testWidgets('A6-2: SceneView disposes owned static layer cache', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 64,
          child: SceneView(imageResolver: (_) => null, staticLayerCache: null),
        ),
      ),
    );
    await tester.pump();

    final viewState = tester.state(find.byType(SceneView)) as dynamic;
    final cache = viewState.debugStaticLayerCache as SceneStaticLayerCache;
    expect(cache.debugBuildCount, greaterThan(0));

    final count0 = cache.debugDisposeCount;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(cache.debugDisposeCount, greaterThan(count0));
  });

  testWidgets('SceneView does not dispose externally provided static cache', (
    tester,
  ) async {
    final cache = SceneStaticLayerCache();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 64,
          child: SceneView(imageResolver: (_) => null, staticLayerCache: cache),
        ),
      ),
    );
    await tester.pump();

    expect(cache.debugBuildCount, greaterThan(0));
    final dispose0 = cache.debugDisposeCount;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(cache.debugDisposeCount, dispose0);
  });

  testWidgets('SceneView disposes only the owned cache when switching', (
    tester,
  ) async {
    final external = SceneStaticLayerCache();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 64,
          child: SceneView(imageResolver: (_) => null, staticLayerCache: null),
        ),
      ),
    );
    await tester.pump();

    final viewState0 = tester.state(find.byType(SceneView)) as dynamic;
    final owned0 = viewState0.debugStaticLayerCache as SceneStaticLayerCache;
    expect(owned0.debugBuildCount, greaterThan(0));

    final ownedDispose0 = owned0.debugDisposeCount;
    final externalDispose0 = external.debugDisposeCount;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 64,
          child: SceneView(
            imageResolver: (_) => null,
            staticLayerCache: external,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(owned0.debugDisposeCount, greaterThan(ownedDispose0));
    expect(external.debugDisposeCount, externalDispose0);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 64,
          child: SceneView(imageResolver: (_) => null, staticLayerCache: null),
        ),
      ),
    );
    await tester.pump();

    final viewState1 = tester.state(find.byType(SceneView)) as dynamic;
    final owned1 = viewState1.debugStaticLayerCache as SceneStaticLayerCache;
    expect(owned1, isNot(same(owned0)));
  });
}
