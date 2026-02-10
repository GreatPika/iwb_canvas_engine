import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';

Layer contentLayer(Scene scene) =>
    scene.layers.firstWhere((layer) => !layer.isBackground);

void main() {
  test('reconfigureInput applies immediately when controller is idle', () {
    final node = RectNode(
      id: 'rect-1',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final scene = Scene(
      layers: [
        Layer(nodes: [node]),
      ],
    );
    final controller = SceneController(
      scene: scene,
      pointerSettings: const PointerInputSettings(tapSlop: 100),
    );
    addTearDown(controller.dispose);

    controller.reconfigureInput(
      pointerSettings: const PointerInputSettings(tapSlop: 0),
      dragStartSlop: null,
      nodeIdGenerator: null,
    );

    expect(controller.pointerSettings.tapSlop, 0);
    expect(controller.dragStartSlop, 0);

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
        position: Offset(10, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(node.position, const Offset(10, 0));
  });

  test('reconfigureInput with equivalent config is a no-op', () {
    final node = RectNode(
      id: 'rect-1',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
      dragStartSlop: 100,
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
    controller.reconfigureInput(
      pointerSettings: controller.pointerSettings,
      dragStartSlop: 0,
      nodeIdGenerator: null,
    );
    controller.reconfigureInput(
      pointerSettings: controller.pointerSettings,
      dragStartSlop: 100,
      nodeIdGenerator: null,
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
        position: Offset(10, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.pointerSettings.tapSlop, 8);
    expect(controller.dragStartSlop, 100);
    expect(node.position, const Offset(0, 0));
  });

  test('reconfigureInput defers dragStartSlop until active pointer ends', () {
    final node = RectNode(
      id: 'rect-1',
      size: const Size(20, 20),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final scene = Scene(
      layers: [
        Layer(nodes: [node]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 100);
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.reconfigureInput(
      pointerSettings: controller.pointerSettings,
      dragStartSlop: 0,
      nodeIdGenerator: null,
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
        position: Offset(10, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(node.position, const Offset(0, 0));

    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(0, 0),
        timestampMs: 30,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(10, 0),
        timestampMs: 40,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 2,
        position: Offset(10, 0),
        timestampMs: 50,
        phase: PointerPhase.up,
      ),
    );

    expect(node.position, const Offset(10, 0));
  });

  test(
    'reconfigureInput switches nodeIdGenerator and supports default fallback',
    () {
      var customASeed = 0;
      var customBSeed = 0;
      final scene = Scene(layers: [Layer()]);
      final controller = SceneController(
        scene: scene,
        nodeIdGenerator: () => 'custom-a-${customASeed++}',
      );
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
          position: Offset(10, 0),
          timestampMs: 10,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(10, 0),
          timestampMs: 20,
          phase: PointerPhase.up,
        ),
      );

      expect(contentLayer(scene).nodes.last.id, 'custom-a-0');

      controller.reconfigureInput(
        pointerSettings: controller.pointerSettings,
        dragStartSlop: null,
        nodeIdGenerator: null,
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 2,
          position: Offset(20, 0),
          timestampMs: 30,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 2,
          position: Offset(30, 0),
          timestampMs: 40,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 2,
          position: Offset(30, 0),
          timestampMs: 50,
          phase: PointerPhase.up,
        ),
      );

      expect(contentLayer(scene).nodes.last.id, 'node-0');

      controller.reconfigureInput(
        pointerSettings: controller.pointerSettings,
        dragStartSlop: null,
        nodeIdGenerator: () => 'custom-b-${customBSeed++}',
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 3,
          position: Offset(40, 0),
          timestampMs: 60,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 3,
          position: Offset(50, 0),
          timestampMs: 70,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 3,
          position: Offset(50, 0),
          timestampMs: 80,
          phase: PointerPhase.up,
        ),
      );

      expect(contentLayer(scene).nodes.last.id, 'custom-b-0');
    },
  );
}
