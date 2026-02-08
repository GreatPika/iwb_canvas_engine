import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // INV:INV-INPUT-SIGNALS-ACTIVE-POINTER-ONLY
  // INV:INV-INPUT-PENDING-TAP-SINGLE-TIMER

  Layer sceneContentLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  SceneController controllerWithTextAndStroke() {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            TextNode(
              id: 'text-1',
              text: 'Hello',
              size: const Size(80, 20),
              fontSize: 14,
              color: const Color(0xFF000000),
            )..position = const Offset(10, 10),
            StrokeNode(
              id: 'stroke-1',
              points: const [Offset(10, 40), Offset(50, 40)],
              thickness: 4,
              color: const Color(0xFF000000),
            ),
          ],
        ),
      ],
    );
    final controller = SceneController(scene: scene);
    addTearDown(controller.dispose);
    return controller;
  }

  SceneController controllerWithSelectedPath() {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            PathNode(
              id: 'path-1',
              svgPathData: 'M0 0 H40 V20 H0 Z',
              strokeColor: const Color(0xFF000000),
              strokeWidth: 2,
            )..position = const Offset(20, 20),
          ],
        ),
      ],
    );
    final controller = SceneController(scene: scene);
    controller.setSelection(const <NodeId>['path-1']);
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> doubleTapWithPointer(
    WidgetTester tester,
    Offset position, {
    required int pointer,
    Duration delay = const Duration(milliseconds: 10),
  }) async {
    final firstTap = await tester.startGesture(position, pointer: pointer);
    await firstTap.up();
    await tester.pump();
    await tester.pump(delay);
    final secondTap = await tester.startGesture(position, pointer: pointer);
    await secondTap.up();
    await tester.pump();
  }

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
            child: SceneView(controller: controller),
          ),
        ),
      );

      expect(find.byType(AnimatedBuilder), findsNothing);

      final renderObject = tester.renderObject<rendering.RenderCustomPaint>(
        find.byType(CustomPaint),
      );
      final painter = renderObject.painter as ScenePainter;
      expect(painter.controller, same(controller));
      expect(painter.imageResolver('missing'), isNull);
      expect(
        painter.thinLineSnapStrategy,
        ThinLineSnapStrategy.autoAxisAlignedThin,
      );

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

  testWidgets('SceneView invokes pointer sample callbacks in order', (
    tester,
  ) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    final calls = <String>[];
    final beforePhases = <PointerPhase>[];
    final afterPhases = <PointerPhase>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 200,
          child: SceneView(
            controller: controller,
            onPointerSampleBefore: (_, sample) {
              calls.add('before:${sample.phase}');
              beforePhases.add(sample.phase);
            },
            onPointerSampleAfter: (_, sample) {
              calls.add('after:${sample.phase}');
              afterPhases.add(sample.phase);
            },
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(beforePhases, [PointerPhase.down, PointerPhase.up]);
    expect(afterPhases, [PointerPhase.down, PointerPhase.up]);
    expect(calls, [
      'before:PointerPhase.down',
      'after:PointerPhase.down',
      'before:PointerPhase.up',
      'after:PointerPhase.up',
    ]);
  });

  testWidgets('SceneView can drag board and attached piece via selection', (
    tester,
  ) async {
    final board = RectNode(
      id: 'board',
      size: const Size(120, 80),
      fillColor: const Color(0xFF2196F3),
    )..position = const Offset(150, 150);
    final piece = RectNode(
      id: 'piece',
      size: const Size(40, 40),
      fillColor: const Color(0xFFE91E63),
    )..position = const Offset(210, 150);

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [board, piece]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            controller: controller,
            imageResolver: (_) => null,
            onPointerSampleAfter: (controller, sample) {
              if (sample.phase != PointerPhase.down) return;
              final scenePoint = toScene(
                sample.position,
                controller.scene.camera.offset,
              );
              final hit = hitTestTopNode(controller.scene, scenePoint);
              if (hit?.id != 'board') return;
              controller.setSelection(const <NodeId>['board', 'piece']);
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(150, 150));
    await gesture.moveTo(const Offset(180, 150));
    await gesture.up();
    await tester.pump();

    expect(board.position, const Offset(180, 150));
    expect(piece.position, const Offset(240, 150));

    final last = actions.lastWhere((a) => a.type == ActionType.transform);
    expect(last.nodeIds, ['board', 'piece']);
  });

  testWidgets('SceneView can omit imageResolver', (tester) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 64,
          child: SceneView(controller: controller),
        ),
      ),
    );

    expect(find.byType(SceneView), findsOneWidget);
  });

  testWidgets('SceneView forwards thin line snap strategy to ScenePainter', (
    tester,
  ) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 64,
          child: SceneView(
            controller: controller,
            thinLineSnapStrategy: ThinLineSnapStrategy.none,
          ),
        ),
      ),
    );

    final renderObject = tester.renderObject<rendering.RenderCustomPaint>(
      find.byType(CustomPaint),
    );
    final painter = renderObject.painter as ScenePainter;
    expect(painter.thinLineSnapStrategy, ThinLineSnapStrategy.none);
  });

  testWidgets('SceneView forwards Directionality to ScenePainter', (
    tester,
  ) async {
    // INV:INV-RENDER-TEXT-DIRECTION-ALIGNMENT
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 100,
          child: SceneView(controller: controller),
        ),
      ),
    );
    final ltrPaint = tester.renderObject<rendering.RenderCustomPaint>(
      find.byType(CustomPaint),
    );
    expect((ltrPaint.painter as ScenePainter).textDirection, TextDirection.ltr);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 200,
          height: 100,
          child: SceneView(controller: controller),
        ),
      ),
    );
    final rtlPaint = tester.renderObject<rendering.RenderCustomPaint>(
      find.byType(CustomPaint),
    );
    expect((rtlPaint.painter as ScenePainter).textDirection, TextDirection.rtl);
  });

  testWidgets('SceneView creates internal controller when missing', (
    tester,
  ) async {
    SceneController? createdController;
    const settings = PointerInputSettings(
      tapSlop: 12,
      doubleTapSlop: 18,
      doubleTapMaxDelayMs: 333,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            pointerSettings: settings,
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
    expect(createdController!.pointerSettings, same(settings));
    expect(createdController!.selectedNodeIds, isEmpty);

    await tester.tapAt(const Offset(150, 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(createdController!.selectedNodeIds, contains('rect-1'));
  });

  testWidgets(
    'SceneView updates owned controller dragStartSlop without recreation',
    (tester) async {
      SceneController? ownedController;
      var readyCalls = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 300,
            child: SceneView(
              dragStartSlop: 100,
              onControllerReady: (controller) {
                readyCalls += 1;
                ownedController = controller;
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

      expect(ownedController, isNotNull);
      expect(readyCalls, 1);

      final firstDrag = await tester.startGesture(const Offset(150, 150));
      await firstDrag.moveTo(const Offset(170, 150));
      await firstDrag.up();
      await tester.pump();

      final nodeAfterFirstDrag = ownedController!.getNode('rect-1') as RectNode;
      expect(nodeAfterFirstDrag.position, const Offset(150, 150));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 300,
            child: SceneView(
              dragStartSlop: 0,
              onControllerReady: (controller) {
                readyCalls += 1;
                ownedController = controller;
              },
            ),
          ),
        ),
      );

      expect(readyCalls, 1);

      final secondDrag = await tester.startGesture(const Offset(150, 150));
      await secondDrag.moveTo(const Offset(170, 150));
      await secondDrag.up();
      await tester.pump();

      final nodeAfterSecondDrag =
          ownedController!.getNode('rect-1') as RectNode;
      expect(nodeAfterSecondDrag.position, const Offset(170, 150));
    },
  );

  testWidgets('SceneView updates owned controller pointerSettings', (
    tester,
  ) async {
    SceneController? ownedController;
    var readyCalls = 0;
    final requests = <EditTextRequested>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            pointerSettings: const PointerInputSettings(
              doubleTapMaxDelayMs: 20,
            ),
            onControllerReady: (controller) {
              readyCalls += 1;
              ownedController = controller;
              controller.addNode(
                TextNode(
                  id: 'text-1',
                  text: 'Hello',
                  size: const Size(200, 60),
                  color: const Color(0xFF000000),
                )..position = const Offset(150, 150),
              );
              controller.editTextRequests.listen(requests.add);
            },
          ),
        ),
      ),
    );

    expect(ownedController, isNotNull);
    expect(readyCalls, 1);

    await doubleTapWithPointer(
      tester,
      const Offset(150, 150),
      pointer: 41,
      delay: const Duration(milliseconds: 80),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(requests, isEmpty);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            pointerSettings: const PointerInputSettings(
              doubleTapMaxDelayMs: 300,
            ),
            onControllerReady: (controller) {
              readyCalls += 1;
              ownedController = controller;
            },
          ),
        ),
      ),
    );

    expect(readyCalls, 1);

    await doubleTapWithPointer(
      tester,
      const Offset(150, 150),
      pointer: 42,
      delay: const Duration(milliseconds: 80),
    );

    expect(requests, hasLength(1));
    expect(requests.single.nodeId, 'text-1');
  });

  testWidgets(
    'SceneView defers pointer tracker refresh until active pointer ends',
    (tester) async {
      final requests = <EditTextRequested>[];

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 300,
            child: SceneView(
              pointerSettings: const PointerInputSettings(
                doubleTapMaxDelayMs: 20,
              ),
              onControllerReady: (controller) {
                controller.addNode(
                  TextNode(
                    id: 'text-1',
                    text: 'Hello',
                    size: const Size(200, 60),
                    color: const Color(0xFF000000),
                  )..position = const Offset(150, 150),
                );
                controller.editTextRequests.listen(requests.add);
              },
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(150, 150));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 300,
            child: SceneView(
              pointerSettings: const PointerInputSettings(
                doubleTapMaxDelayMs: 300,
              ),
            ),
          ),
        ),
      );

      await gesture.up();
      await tester.pump();
      expect(requests, isEmpty);

      await doubleTapWithPointer(
        tester,
        const Offset(150, 150),
        pointer: 43,
        delay: const Duration(milliseconds: 80),
      );

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, 'text-1');
    },
  );

  testWidgets('SceneView updates owned controller nodeIdGenerator', (
    tester,
  ) async {
    SceneController? ownedController;
    var readyCalls = 0;
    var seedA = 0;
    var seedB = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            nodeIdGenerator: () => 'a-${seedA++}',
            onControllerReady: (controller) {
              readyCalls += 1;
              ownedController = controller;
              controller.setMode(CanvasMode.draw);
              controller.setDrawTool(DrawTool.pen);
            },
          ),
        ),
      ),
    );

    final firstStroke = await tester.startGesture(const Offset(40, 40));
    await firstStroke.moveTo(const Offset(60, 40));
    await firstStroke.up();
    await tester.pump();

    final firstId = sceneContentLayer(ownedController!.scene).nodes.last.id;
    expect(firstId, 'a-0');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SceneView(
            nodeIdGenerator: () => 'b-${seedB++}',
            onControllerReady: (controller) {
              readyCalls += 1;
              ownedController = controller;
            },
          ),
        ),
      ),
    );

    expect(readyCalls, 1);

    final secondStroke = await tester.startGesture(const Offset(80, 40));
    await secondStroke.moveTo(const Offset(100, 40));
    await secondStroke.up();
    await tester.pump();

    final secondId = sceneContentLayer(ownedController!.scene).nodes.last.id;
    expect(secondId, 'b-0');
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

  testWidgets(
    'SceneView ignores input config updates for external controller',
    (tester) async {
      String externalGenerator() => 'ext';
      final externalController = SceneController(
        scene: Scene(layers: [Layer()]),
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 20),
        dragStartSlop: 7,
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
              pointerSettings: const PointerInputSettings(
                doubleTapMaxDelayMs: 200,
              ),
              dragStartSlop: 1,
              nodeIdGenerator: externalGenerator,
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
              controller: externalController,
              pointerSettings: const PointerInputSettings(
                doubleTapMaxDelayMs: 450,
              ),
              dragStartSlop: 0,
              nodeIdGenerator: () => 'changed',
            ),
          ),
        ),
      );

      expect(externalController.pointerSettings.doubleTapMaxDelayMs, 20);
      expect(externalController.dragStartSlop, 7);
    },
  );

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

    await doubleTapWithPointer(tester, const Offset(150, 150), pointer: 44);

    expect(requests, hasLength(1));
    expect(requests.single.nodeId, 'text-1');
    expect(requests.single.position, const Offset(150, 150));
  });

  testWidgets('SceneView dispatches double-tap signals across pointer ids', (
    tester,
  ) async {
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

    final tapA = await tester.startGesture(const Offset(150, 150), pointer: 45);
    await tapA.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    final tapB = await tester.startGesture(const Offset(150, 150), pointer: 46);
    await tapB.up();
    await tester.pump();

    expect(requests, hasLength(1));
    expect(requests.single.nodeId, 'text-1');
    expect(requests.single.position, const Offset(150, 150));
  });

  testWidgets(
    'SceneView ignores non-active pointer double-tap while gesture is active',
    (tester) async {
      final scene = Scene(
        layers: [
          Layer(
            nodes: [
              RectNode(
                id: 'rect-1',
                size: const Size(80, 80),
                fillColor: const Color(0xFF90CAF9),
              )..position = const Offset(60, 150),
              TextNode(
                id: 'text-1',
                text: 'Hello',
                size: const Size(200, 60),
                color: const Color(0xFF000000),
              )..position = const Offset(220, 150),
            ],
          ),
        ],
      );
      final controller = SceneController(
        scene: scene,
        dragStartSlop: 0,
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 300),
      );
      addTearDown(controller.dispose);
      final requests = <EditTextRequested>[];
      controller.editTextRequests.listen(requests.add);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 320,
            height: 260,
            child: SceneView(
              controller: controller,
              imageResolver: (_) => null,
            ),
          ),
        ),
      );

      final drag = await tester.startGesture(const Offset(60, 150), pointer: 1);
      await drag.moveTo(const Offset(90, 150));

      final tapA = await tester.startGesture(
        const Offset(220, 150),
        pointer: 2,
      );
      await tapA.up();
      await tester.pump(const Duration(milliseconds: 10));
      final tapB = await tester.startGesture(
        const Offset(220, 150),
        pointer: 2,
      );
      await tapB.up();
      await tester.pump();

      await drag.up();
      await tester.pump();

      expect(requests, isEmpty);
    },
  );

  testWidgets(
    'SceneView keeps a single pending-tap timer during move samples',
    (tester) async {
      final controller = SceneController(
        scene: Scene(layers: [Layer()]),
        pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 300),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 300,
            child: SceneView(controller: controller),
          ),
        ),
      );

      final firstTap = await tester.startGesture(
        const Offset(30, 30),
        pointer: 1,
      );
      await firstTap.up();
      await tester.pump();

      final viewState = tester.state(find.byType(SceneView)) as dynamic;
      final baselineFlushTs = viewState.debugPendingTapFlushTimestampMs as int?;
      expect(viewState.debugHasPendingTapTimer as bool, isTrue);
      expect(baselineFlushTs, isNotNull);

      final drag = await tester.startGesture(const Offset(60, 60), pointer: 2);
      await tester.pump(const Duration(milliseconds: 5));
      await drag.moveTo(const Offset(120, 60));
      await tester.pump(const Duration(milliseconds: 5));
      await drag.moveTo(const Offset(180, 60));
      await tester.pump(const Duration(milliseconds: 5));
      await drag.cancel();
      await tester.pump();

      expect(viewState.debugHasPendingTapTimer as bool, isTrue);
      expect(
        viewState.debugPendingTapFlushTimestampMs as int?,
        baselineFlushTs,
      );
    },
  );

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

  testWidgets('P1: SceneView creates owned text/stroke caches by default', (
    tester,
  ) async {
    final controller = controllerWithTextAndStroke();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
    await tester.pump();

    final viewState = tester.state(find.byType(SceneView)) as dynamic;
    final textCache = viewState.debugTextLayoutCache as SceneTextLayoutCache;
    final strokeCache = viewState.debugStrokePathCache as SceneStrokePathCache;
    final pathCache = viewState.debugPathMetricsCache as ScenePathMetricsCache;
    expect(textCache.debugSize, greaterThan(0));
    expect(strokeCache.debugSize, greaterThan(0));

    final renderObject = tester.renderObject<rendering.RenderCustomPaint>(
      find.byType(CustomPaint),
    );
    final painter = renderObject.painter as ScenePainter;
    expect(painter.textLayoutCache, same(textCache));
    expect(painter.strokePathCache, same(strokeCache));
    expect(painter.pathMetricsCache, same(pathCache));
  });

  testWidgets('P1: SceneView clears owned text/stroke caches on dispose', (
    tester,
  ) async {
    final controller = controllerWithTextAndStroke();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
    await tester.pump();

    final viewState = tester.state(find.byType(SceneView)) as dynamic;
    final textCache = viewState.debugTextLayoutCache as SceneTextLayoutCache;
    final strokeCache = viewState.debugStrokePathCache as SceneStrokePathCache;
    expect(textCache.debugSize, greaterThan(0));
    expect(strokeCache.debugSize, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(textCache.debugSize, 0);
    expect(strokeCache.debugSize, 0);
  });

  testWidgets('P1: SceneView does not clear external text/stroke caches', (
    tester,
  ) async {
    final controller = controllerWithTextAndStroke();
    final textCache = SceneTextLayoutCache(maxEntries: 8);
    final strokeCache = SceneStrokePathCache(maxEntries: 8);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(
            controller: controller,
            imageResolver: (_) => null,
            textLayoutCache: textCache,
            strokePathCache: strokeCache,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(textCache.debugSize, greaterThan(0));
    expect(strokeCache.debugSize, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(textCache.debugSize, greaterThan(0));
    expect(strokeCache.debugSize, greaterThan(0));
  });

  testWidgets('P1: SceneView clears only owned caches when switching', (
    tester,
  ) async {
    final controller = controllerWithTextAndStroke();
    final externalText = SceneTextLayoutCache(maxEntries: 8);
    final externalStroke = SceneStrokePathCache(maxEntries: 8);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
    await tester.pump();

    final viewState0 = tester.state(find.byType(SceneView)) as dynamic;
    final ownedText0 = viewState0.debugTextLayoutCache as SceneTextLayoutCache;
    final ownedStroke0 =
        viewState0.debugStrokePathCache as SceneStrokePathCache;
    expect(ownedText0.debugSize, greaterThan(0));
    expect(ownedStroke0.debugSize, greaterThan(0));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(
            controller: controller,
            imageResolver: (_) => null,
            textLayoutCache: externalText,
            strokePathCache: externalStroke,
          ),
        ),
      ),
    );
    await tester.pump();

    // The previously owned caches must be cleared when switching away.
    expect(ownedText0.debugSize, 0);
    expect(ownedStroke0.debugSize, 0);

    final viewState1 = tester.state(find.byType(SceneView)) as dynamic;
    expect(viewState1.debugTextLayoutCache, same(externalText));
    expect(viewState1.debugStrokePathCache, same(externalStroke));

    final externalTextSize = externalText.debugSize;
    final externalStrokeSize = externalStroke.debugSize;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
    await tester.pump();

    // Externally owned caches must stay intact.
    expect(externalText.debugSize, externalTextSize);
    expect(externalStroke.debugSize, externalStrokeSize);

    final viewState2 = tester.state(find.byType(SceneView)) as dynamic;
    final ownedText1 = viewState2.debugTextLayoutCache as SceneTextLayoutCache;
    final ownedStroke1 =
        viewState2.debugStrokePathCache as SceneStrokePathCache;
    expect(ownedText1, isNot(same(ownedText0)));
    expect(ownedStroke1, isNot(same(ownedStroke0)));
  });

  testWidgets('P1: SceneView clears owned path metrics cache on dispose', (
    tester,
  ) async {
    final controller = controllerWithSelectedPath();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
    await tester.pump();

    final viewState = tester.state(find.byType(SceneView)) as dynamic;
    final pathCache = viewState.debugPathMetricsCache as ScenePathMetricsCache;
    expect(pathCache.debugSize, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(pathCache.debugSize, 0);
  });

  testWidgets('P1: SceneView does not clear external path metrics cache', (
    tester,
  ) async {
    final controller = controllerWithSelectedPath();
    final pathCache = ScenePathMetricsCache(maxEntries: 8);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(
            controller: controller,
            imageResolver: (_) => null,
            pathMetricsCache: pathCache,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(pathCache.debugSize, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(pathCache.debugSize, greaterThan(0));
  });

  testWidgets('P1: SceneView clears only owned path metrics cache on switch', (
    tester,
  ) async {
    final controller = controllerWithSelectedPath();
    final externalPath = ScenePathMetricsCache(maxEntries: 8);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
    await tester.pump();

    final viewState0 = tester.state(find.byType(SceneView)) as dynamic;
    final ownedPath0 =
        viewState0.debugPathMetricsCache as ScenePathMetricsCache;
    expect(ownedPath0.debugSize, greaterThan(0));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(
            controller: controller,
            imageResolver: (_) => null,
            pathMetricsCache: externalPath,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(ownedPath0.debugSize, 0);
    final viewState1 = tester.state(find.byType(SceneView)) as dynamic;
    expect(viewState1.debugPathMetricsCache, same(externalPath));

    final externalPathSize = externalPath.debugSize;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 96,
          height: 96,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );
    await tester.pump();

    expect(externalPath.debugSize, externalPathSize);
    final viewState2 = tester.state(find.byType(SceneView)) as dynamic;
    final ownedPath1 =
        viewState2.debugPathMetricsCache as ScenePathMetricsCache;
    expect(ownedPath1, isNot(same(ownedPath0)));
  });
}
