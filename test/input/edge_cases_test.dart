import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // INV:INV-INPUT-TIMESTAMP-MONOTONIC
  // INV:INV-INPUT-ERASER-COMMIT-ON-UP
  // INV:INV-INPUT-LINE-PENDING-TIMER

  RectNode rectNode(
    String id,
    Offset position, {
    bool isVisible = true,
    bool isSelectable = true,
    bool isDeletable = true,
    bool isTransformable = true,
  }) {
    return RectNode(
      id: id,
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isVisible: isVisible,
      isSelectable: isSelectable,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    )..position = position;
  }

  Layer firstNonBackgroundLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  testWidgets('SceneController setters notify only on changes', (tester) async {
    final controller = SceneController();
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setDrawColor(SceneDefaults.penColors.first);
    controller.setDrawColor(const Color(0xFF112233));
    controller.setDrawColor(const Color(0xFF112233));

    controller.setBackgroundColor(SceneDefaults.backgroundColors.first);
    controller.setBackgroundColor(const Color(0xFFFAFAFA));

    controller.setGridEnabled(false);
    controller.setGridEnabled(true);

    controller.setGridCellSize(SceneDefaults.gridSizes.first);
    controller.setGridCellSize(42);

    controller.setCameraOffset(Offset.zero);
    controller.setCameraOffset(const Offset(10, -5));

    controller.notifySceneChanged();

    await tester.pump();

    expect(notifications, greaterThan(0));
    expect(controller.drawColor, const Color(0xFF112233));
    expect(controller.scene.background.color, const Color(0xFFFAFAFA));
    expect(controller.scene.background.grid.isEnabled, isTrue);
    expect(controller.scene.background.grid.cellSize, 42);
    expect(controller.scene.camera.offset, const Offset(10, -5));
  });

  test(
    'rotate/flip default timestamps are monotonic after pointer events',
    () async {
      final node = rectNode('r1', const Offset(0, 0));
      final controller = SceneController(
        scene: Scene(
          layers: [
            Layer(nodes: [node]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 10,
          phase: PointerPhase.up,
        ),
      );

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.rotateSelection(clockwise: false);
      controller.flipSelectionVertical();
      controller.flipSelectionHorizontal();

      expect(actions, hasLength(3));
      expect(actions.first.type, ActionType.transform);
      expect(actions.first.payload, contains('delta'));
      expect(actions.first.timestampMs, 11);
      expect(actions[1].type, ActionType.transform);
      expect(actions[1].payload, contains('delta'));
      expect(actions[1].timestampMs, 12);
      expect(actions[2].type, ActionType.transform);
      expect(actions[2].payload, contains('delta'));
      expect(actions[2].timestampMs, 13);

      bool isNonIdentityDelta(Map<String, Object?> payload) {
        final delta = (payload['delta'] as Map).cast<String, num>();
        final a = delta['a']?.toDouble() ?? 0;
        final d = delta['d']?.toDouble() ?? 0;
        final tx = delta['tx']?.toDouble() ?? 0;
        final ty = delta['ty']?.toDouble() ?? 0;
        return a != 1.0 || d != 1.0 || tx != 0.0 || ty != 0.0;
      }

      expect(isNonIdentityDelta(actions.first.payload!), isTrue);
      expect(isNonIdentityDelta(actions[1].payload!), isTrue);
      expect(isNonIdentityDelta(actions[2].payload!), isTrue);
    },
  );

  test('deleteSelection/clearScene default timestamps are monotonic', () {
    final deletable = rectNode('del', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [deletable]),
      ],
    );
    final controller = SceneController(scene: scene);
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.deleteSelection();

    expect(actions.single.type, ActionType.delete);
    expect(actions.single.timestampMs, 11);
    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);

    firstNonBackgroundLayer(scene).nodes.add(rectNode('a', const Offset(0, 0)));
    controller.clearScene();

    expect(actions.last.type, ActionType.clear);
    expect(actions.last.timestampMs, 12);
    expect(scene.layers, hasLength(1));
    expect(scene.layers.first.isBackground, isTrue);
  });

  test('default timestamp follows explicit command timestamp watermark', () {
    final node = rectNode('r1', const Offset(0, 0));
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.rotateSelection(clockwise: true, timestampMs: 100);
    controller.flipSelectionVertical();

    expect(actions, hasLength(2));
    expect(actions.first.timestampMs, 100);
    expect(actions.last.timestampMs, 101);
  });

  test('explicit timestamp hint that goes backwards is normalized forward', () {
    final node = rectNode('r1', const Offset(0, 0));
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.setSelection(const ['r1']);
    controller.rotateSelection(clockwise: true, timestampMs: 100);
    controller.flipSelectionVertical(timestampMs: 10);

    expect(actions, hasLength(2));
    expect(actions.first.timestampMs, 100);
    expect(actions.last.timestampMs, 101);
  });

  test('explicit timestamp hint is preserved when already ahead of cursor', () {
    final node = rectNode('r1', const Offset(0, 0));
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.setSelection(const ['r1']);
    controller.rotateSelection(clockwise: true, timestampMs: 77);

    expect(actions, hasLength(1));
    expect(actions.single.timestampMs, 77);
  });

  test('epoch-like hint keeps subsequent pointer-driven actions monotonic', () {
    final node = rectNode('r1', const Offset(0, 0));
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.setSelection(const ['r1']);
    controller.rotateSelection(clockwise: true, timestampMs: 1700000000000);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    controller.flipSelectionHorizontal();

    expect(actions, hasLength(2));
    expect(actions.first.timestampMs, 1700000000000);
    expect(actions.last.timestampMs, 1700000000003);
  });

  test('marquee on empty area keeps selection empty', () {
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [rectNode('far', const Offset(1000, 1000))]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(-20, -20),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.selectedNodeIds, isEmpty);
    expect(
      actions.where((event) => event.type == ActionType.selectMarquee),
      isEmpty,
    );
  });

  test('move mode cancel clears marquee rect and releases pointer capture', () {
    final node = rectNode('r1', const Offset(0, 0));
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );
    expect(controller.selectedNodeIds, {'r1'});

    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(50, 50),
        timestampMs: 20,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(60, 60),
        timestampMs: 30,
        phase: PointerPhase.move,
      ),
    );
    expect(controller.selectionRect, isNotNull);
    expect(controller.selectedNodeIds, isEmpty);

    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(60, 60),
        timestampMs: 40,
        phase: PointerPhase.cancel,
      ),
    );
    expect(controller.selectionRect, isNull);

    controller.handlePointer(
      const PointerSample(
        pointerId: 3,
        position: Offset(0, 0),
        timestampMs: 50,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 3,
        position: Offset(0, 0),
        timestampMs: 60,
        phase: PointerPhase.up,
      ),
    );
    expect(controller.selectedNodeIds, {'r1'});
  });

  test('draw cancel removes active stroke', () {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.pen);

    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    expect(firstNonBackgroundLayer(scene).nodes, isNotEmpty);

    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(0, 0),
        timestampMs: 1,
        phase: PointerPhase.cancel,
      ),
    );

    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
  });

  test('switching draw->move resets draw state', () {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.pen);

    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    expect(firstNonBackgroundLayer(scene).nodes, isNotEmpty);

    controller.setMode(CanvasMode.move);
    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
  });

  test('switching draw->move removes active line preview', () {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.line);

    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(10, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    expect(firstNonBackgroundLayer(scene).nodes, isNotEmpty);

    controller.setMode(CanvasMode.move);
    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
  });

  test('line drag clears pending two-tap start', () {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.line);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.hasPendingLineStart, isTrue);
    expect(controller.pendingLineStart, const Offset(0, 0));
    expect(controller.pendingLineTimestampMs, 10);

    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(10, 0),
        timestampMs: 100,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(30, 0),
        timestampMs: 110,
        phase: PointerPhase.move,
      ),
    );

    expect(controller.hasPendingLineStart, isFalse);
    expect(firstNonBackgroundLayer(scene).nodes.single, isA<LineNode>());
  });

  test('line drag updates existing line end', () {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.line);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(10, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 0),
        timestampMs: 20,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 0),
        timestampMs: 30,
        phase: PointerPhase.up,
      ),
    );

    final line = firstNonBackgroundLayer(scene).nodes.single as LineNode;
    expect(line.transform.applyToPoint(line.end), const Offset(20, 0));
    expect(actions.single.type, ActionType.drawLine);
  });

  testWidgets('pending two-tap line expires after timeout without new events', (
    tester,
  ) async {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.line);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 1,
        phase: PointerPhase.up,
      ),
    );
    expect(controller.hasPendingLineStart, isTrue);

    await tester.pump(const Duration(seconds: 11));

    expect(controller.hasPendingLineStart, isFalse);
  });

  test('drawing on background-only scene creates annotation layer', () {
    final background = Layer(isBackground: true);
    final scene = Scene(layers: [background]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.pen);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(1, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(scene.layers, hasLength(2));
    expect(scene.layers.first.isBackground, isTrue);
    expect(scene.layers.last.isBackground, isFalse);
    expect(scene.layers.last.nodes.single, isA<StrokeNode>());
  });

  test('eraser emits action only when something is deleted', () async {
    final line = LineNode(
      id: 'line-1',
      start: const Offset(100, 100),
      end: const Offset(120, 100),
      thickness: 4,
      color: const Color(0xFF000000),
    );

    final scene = Scene(
      layers: [
        Layer(nodes: [line]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(1, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(firstNonBackgroundLayer(scene).nodes, hasLength(1));
    expect(actions, isEmpty);
  });

  test('eraser move + cancel does not delete nodes and emits no action', () {
    final line = LineNode(
      id: 'line-1',
      start: const Offset(-10, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [line]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(-5, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(5, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(5, 0),
        timestampMs: 20,
        phase: PointerPhase.cancel,
      ),
    );

    expect(firstNonBackgroundLayer(scene).nodes.single.id, 'line-1');
    expect(actions.where((event) => event.type == ActionType.erase), isEmpty);
  });

  test('eraser move + setMode does not delete nodes and emits no action', () {
    final line = LineNode(
      id: 'line-1',
      start: const Offset(-10, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [line]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(-5, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(5, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.setMode(CanvasMode.move);

    expect(firstNonBackgroundLayer(scene).nodes.single.id, 'line-1');
    expect(actions.where((event) => event.type == ActionType.erase), isEmpty);
  });

  test('eraser deletes a line with single-point input', () async {
    final line = LineNode(
      id: 'line-1',
      start: const Offset(-10, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final scene = Scene(
      layers: [
        Layer(nodes: [line]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 1,
        phase: PointerPhase.up,
      ),
    );

    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
    expect(actions.single.type, ActionType.erase);
  });

  test('eraser deletes a single-point stroke', () async {
    final stroke = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(0, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final scene = Scene(
      layers: [
        Layer(nodes: [stroke]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(1, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(1, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
  });

  test('eraser skips background layers', () async {
    final backgroundStroke = StrokeNode(
      id: 'bg-stroke',
      points: const [Offset(0, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final foregroundStroke = StrokeNode(
      id: 'fg-stroke',
      points: const [Offset(0, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final scene = Scene(
      layers: [
        Layer(nodes: [backgroundStroke], isBackground: true),
        Layer(nodes: [foregroundStroke]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(scene.layers.first.nodes.single.id, 'bg-stroke');
    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
    expect(actions.single.type, ActionType.erase);
    expect(actions.single.nodeIds, ['fg-stroke']);
  });

  test('eraser deletes a stroke polyline with single-point input', () async {
    final stroke = StrokeNode(
      id: 'stroke-1',
      points: const [Offset(-10, 0), Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final scene = Scene(
      layers: [
        Layer(nodes: [stroke]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
  });

  test('marquee selection skips invisible and non-selectable nodes', () {
    // INV:INV-INPUT-BACKGROUND-NONINTERACTIVE-NONDELETABLE
    final visible = rectNode('a', const Offset(0, 0));
    final hidden = rectNode('b', const Offset(0, 0), isVisible: false);
    final nonSelectable = rectNode(
      'c',
      const Offset(0, 0),
      isSelectable: false,
    );
    final backgroundNode = rectNode('bg', const Offset(0, 0));

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(isBackground: true, nodes: [backgroundNode]),
          Layer(nodes: [visible, hidden, nonSelectable]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    void marquee(Rect rect) {
      controller.handlePointer(
        PointerSample(
          pointerId: 1,
          position: rect.topLeft,
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        PointerSample(
          pointerId: 1,
          position: rect.bottomRight,
          timestampMs: 10,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        PointerSample(
          pointerId: 1,
          position: rect.bottomRight,
          timestampMs: 20,
          phase: PointerPhase.up,
        ),
      );
    }

    marquee(const Rect.fromLTRB(-20, -20, 20, 20));
    expect(controller.selectedNodeIds, {'a'});

    marquee(const Rect.fromLTRB(-20, -20, 20, 20));
    expect(controller.selectedNodeIds, {'a'});
  });

  test('rotateSelection rotates stroke geometry', () {
    final stroke = StrokeNode(
      id: 'stroke',
      points: [const Offset(0, 0), const Offset(10, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [stroke]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(-20, -20),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    controller.rotateSelection(clockwise: true, timestampMs: 30);
    final first = stroke.transform.applyToPoint(stroke.points.first);
    expect(first.dx, closeTo(5, 0.001));
    expect(first.dy, closeTo(-5, 0.001));
  });

  test('flipSelectionVertical mirrors line geometry', () {
    final line = LineNode(
      id: 'line',
      start: const Offset(0, 0),
      end: const Offset(10, 0),
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [line]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(-20, -20),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    controller.flipSelectionVertical(timestampMs: 30);
    final start = line.transform.applyToPoint(line.start);
    final end = line.transform.applyToPoint(line.end);
    expect(start.dx, closeTo(10, 0.001));
    expect(end.dx, closeTo(0, 0.001));
  });

  test('flipSelectionHorizontal mirrors line geometry', () {
    final line = LineNode(
      id: 'line',
      start: const Offset(0, 0),
      end: const Offset(0, 10),
      thickness: 2,
      color: const Color(0xFF000000),
    );

    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [line]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(-20, -20),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(20, 20),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    controller.flipSelectionHorizontal(timestampMs: 30);
    final start = line.transform.applyToPoint(line.start);
    final end = line.transform.applyToPoint(line.end);
    expect(start.dy, closeTo(10, 0.001));
    expect(end.dy, closeTo(0, 0.001));
  });
}
