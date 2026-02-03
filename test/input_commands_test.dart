import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void marqueeSelect(SceneController controller, Rect rect) {
    controller.handlePointer(
      PointerSample(
        pointerId: 99,
        position: rect.topLeft,
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 99,
        position: rect.bottomRight,
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 99,
        position: rect.bottomRight,
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );
  }

  RectNode rectNode(String id, Offset position, {bool transformable = true}) {
    return RectNode(
      id: id,
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isTransformable: transformable,
    )..position = position;
  }

  test('clearSelection clears non-empty selection and notifies', () {
    final node = rectNode('rect-1', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [node]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));
    expect(controller.selectedNodeIds, contains('rect-1'));

    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.clearSelection();

    expect(controller.selectedNodeIds, isEmpty);
    expect(notifications, greaterThan(0));
  });

  test('debug revisions behave consistently', () {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);

    final sceneRev0 = controller.debugSceneRevision;
    final selRev0 = controller.debugSelectionRevision;

    controller.addNode(rectNode('rect-1', const Offset(0, 0)));
    expect(controller.debugSceneRevision, greaterThan(sceneRev0));

    void tapAt(Offset position, int timestampMs) {
      controller.handlePointer(
        PointerSample(
          pointerId: 1,
          position: position,
          timestampMs: timestampMs,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        PointerSample(
          pointerId: 1,
          position: position,
          timestampMs: timestampMs + 10,
          phase: PointerPhase.up,
        ),
      );
    }

    tapAt(const Offset(0, 0), 0);
    final selRev1 = controller.debugSelectionRevision;
    expect(selRev1, greaterThan(selRev0));

    tapAt(const Offset(0, 0), 100);
    expect(controller.debugSelectionRevision, selRev1);
  });

  test('rotateSelection rotates around selection center', () {
    final left = rectNode('left', const Offset(0, 0));
    final right = rectNode('right', const Offset(10, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [left, right]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));

    controller.rotateSelection(clockwise: true, timestampMs: 40);

    expect(left.position.dx, closeTo(5, 0.001));
    expect(left.position.dy, closeTo(-5, 0.001));
    expect(right.position.dx, closeTo(5, 0.001));
    expect(right.position.dy, closeTo(5, 0.001));
    expect(left.rotationDeg, 90);
    expect(right.rotationDeg, 90);
  });

  test('rotateSelection skips non-transformable nodes and centers on them', () {
    final transformable = rectNode('t', const Offset(0, 0));
    final nonTransformable = rectNode(
      'nt',
      const Offset(100, 0),
      transformable: false,
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [transformable, nonTransformable]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 120, 20));

    controller.rotateSelection(clockwise: true, timestampMs: 40);

    expect(transformable.position.dx, closeTo(0, 0.001));
    expect(transformable.position.dy, closeTo(0, 0.001));
    expect(transformable.rotationDeg, 90);
    expect(nonTransformable.position, const Offset(100, 0));
    expect(nonTransformable.rotationDeg, 0);
  });

  test('flipSelectionVertical mirrors around center x', () {
    final left = rectNode('left', const Offset(0, 0));
    final right = rectNode('right', const Offset(10, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [left, right]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));

    controller.flipSelectionVertical(timestampMs: 40);

    expect(left.position.dx, closeTo(10, 0.001));
    expect(right.position.dx, closeTo(0, 0.001));
    expect(left.transform.a, closeTo(-1, 0.001));
    expect(left.transform.d, closeTo(1, 0.001));
    expect(right.transform.a, closeTo(-1, 0.001));
    expect(right.transform.d, closeTo(1, 0.001));
  });

  test('flipSelectionHorizontal mirrors around center y', () {
    final top = rectNode('top', const Offset(0, 0));
    final bottom = rectNode('bottom', const Offset(0, 10));
    final scene = Scene(
      layers: [
        Layer(nodes: [top, bottom]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));

    controller.flipSelectionHorizontal(timestampMs: 40);

    expect(top.position.dy, closeTo(10, 0.001));
    expect(bottom.position.dy, closeTo(0, 0.001));
    expect(top.transform.a, closeTo(1, 0.001));
    expect(top.transform.d, closeTo(-1, 0.001));
    expect(bottom.transform.a, closeTo(1, 0.001));
    expect(bottom.transform.d, closeTo(-1, 0.001));
  });

  test(
    'flipSelectionVertical skips non-transformable nodes and centers on them',
    () {
      final transformable = rectNode('t', const Offset(0, 0));
      final nonTransformable = rectNode(
        'nt',
        const Offset(100, 0),
        transformable: false,
      );
      final scene = Scene(
        layers: [
          Layer(nodes: [transformable, nonTransformable]),
        ],
      );
      final controller = SceneController(scene: scene, dragStartSlop: 0);
      marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 120, 20));

      controller.flipSelectionVertical(timestampMs: 40);

      expect(transformable.position.dx, closeTo(0, 0.001));
      expect(transformable.position.dy, closeTo(0, 0.001));
      expect(transformable.transform.a, closeTo(-1, 0.001));
      expect(transformable.transform.d, closeTo(1, 0.001));
      expect(nonTransformable.position, const Offset(100, 0));
      expect(nonTransformable.transform.a, closeTo(1, 0.001));
      expect(nonTransformable.transform.d, closeTo(1, 0.001));
    },
  );

  test(
    'flipSelectionHorizontal skips non-transformable nodes and centers on them',
    () {
      final transformable = rectNode('t', const Offset(0, 0));
      final nonTransformable = rectNode(
        'nt',
        const Offset(0, 100),
        transformable: false,
      );
      final scene = Scene(
        layers: [
          Layer(nodes: [transformable, nonTransformable]),
        ],
      );
      final controller = SceneController(scene: scene, dragStartSlop: 0);
      marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 120));

      controller.flipSelectionHorizontal(timestampMs: 40);

      expect(transformable.position.dx, closeTo(0, 0.001));
      expect(transformable.position.dy, closeTo(0, 0.001));
      expect(transformable.transform.a, closeTo(1, 0.001));
      expect(transformable.transform.d, closeTo(-1, 0.001));
      expect(nonTransformable.position, const Offset(0, 100));
      expect(nonTransformable.transform.a, closeTo(1, 0.001));
      expect(nonTransformable.transform.d, closeTo(1, 0.001));
    },
  );

  test('rotateSelection rotates line geometry', () {
    final line = LineNode(
      id: 'line',
      start: const Offset(0, 0),
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
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 20));

    controller.rotateSelection(clockwise: true, timestampMs: 40);

    final start = line.transform.applyToPoint(line.start);
    final end = line.transform.applyToPoint(line.end);
    expect(start.dx, closeTo(5, 0.001));
    expect(start.dy, closeTo(-5, 0.001));
    expect(end.dx, closeTo(5, 0.001));
    expect(end.dy, closeTo(5, 0.001));
  });

  test('flipSelectionVertical mirrors stroke geometry', () {
    final stroke = StrokeNode(
      id: 'stroke',
      points: [const Offset(0, 0), const Offset(10, 0), const Offset(20, 0)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [stroke]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 40, 20));

    controller.flipSelectionVertical(timestampMs: 40);

    final p0 = stroke.transform.applyToPoint(stroke.points[0]);
    final p1 = stroke.transform.applyToPoint(stroke.points[1]);
    final p2 = stroke.transform.applyToPoint(stroke.points[2]);
    expect(p0.dx, closeTo(20, 0.001));
    expect(p1.dx, closeTo(10, 0.001));
    expect(p2.dx, closeTo(0, 0.001));
  });

  test('flipSelectionHorizontal mirrors stroke geometry', () {
    final stroke = StrokeNode(
      id: 'stroke',
      points: [const Offset(0, 0), const Offset(0, 10), const Offset(0, 20)],
      thickness: 2,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      layers: [
        Layer(nodes: [stroke]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 20, 40));

    controller.flipSelectionHorizontal(timestampMs: 40);

    final p0 = stroke.transform.applyToPoint(stroke.points[0]);
    final p1 = stroke.transform.applyToPoint(stroke.points[1]);
    final p2 = stroke.transform.applyToPoint(stroke.points[2]);
    expect(p0.dy, closeTo(20, 0.001));
    expect(p1.dy, closeTo(10, 0.001));
    expect(p2.dy, closeTo(0, 0.001));
  });

  test('deleteSelection removes deletable nodes only', () {
    final deletable = rectNode('del', const Offset(0, 0));
    final locked = RectNode(
      id: 'keep',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isDeletable: false,
    )..position = const Offset(20, 0);
    final scene = Scene(
      layers: [
        Layer(nodes: [deletable, locked]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    marqueeSelect(controller, const Rect.fromLTRB(-20, -20, 30, 20));

    controller.deleteSelection(timestampMs: 40);

    expect(scene.layers.first.nodes, [locked]);
  });

  test('clearScene removes nodes from non-background layers', () {
    final background = Layer(
      isBackground: true,
      nodes: [rectNode('bg', const Offset(0, 0))],
    );
    final foreground = Layer(
      nodes: [
        rectNode('a', const Offset(0, 0)),
        rectNode('b', const Offset(10, 0)),
      ],
    );
    final scene = Scene(layers: [background, foreground]);
    final controller = SceneController(scene: scene);

    controller.clearScene(timestampMs: 10);

    expect(scene.layers.first.nodes, hasLength(1));
    expect(scene.layers.last.nodes, isEmpty);
  });
}
