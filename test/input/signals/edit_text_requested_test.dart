import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // INV:INV-INPUT-TIMESTAMP-MONOTONIC

  TextNode textNode(String id, Offset position) {
    return TextNode(
      id: id,
      text: 'Hello',
      size: const Size(40, 20),
      color: const Color(0xFF000000),
    )..position = position;
  }

  test('double tap on text emits EditTextRequested', () {
    final text = textNode('text-1', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [text]),
      ],
    );
    final controller = SceneController(scene: scene);

    final requests = <EditTextRequested>[];
    controller.editTextRequests.listen(requests.add);

    controller.handlePointerSignal(
      const PointerSignal(
        type: PointerSignalType.doubleTap,
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 100,
        kind: PointerDeviceKind.touch,
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single.nodeId, 'text-1');
    expect(requests.single.timestampMs, 100);
    expect(requests.single.position, const Offset(0, 0));
  });

  test('double tap ignored in draw mode', () {
    final text = textNode('text-1', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [text]),
      ],
    );
    final controller = SceneController(scene: scene);
    controller.setMode(CanvasMode.draw);

    final requests = <EditTextRequested>[];
    controller.editTextRequests.listen(requests.add);

    controller.handlePointerSignal(
      const PointerSignal(
        type: PointerSignalType.doubleTap,
        pointerId: 2,
        position: Offset(0, 0),
        timestampMs: 120,
        kind: PointerDeviceKind.touch,
      ),
    );

    expect(requests, isEmpty);
  });

  test('double tap timestamp hint is normalized after higher watermark', () {
    final text = textNode('text-1', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [text]),
      ],
    );
    final controller = SceneController(scene: scene);
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 1000,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 1010,
        phase: PointerPhase.up,
      ),
    );

    final requests = <EditTextRequested>[];
    final sub = controller.editTextRequests.listen(requests.add);
    addTearDown(sub.cancel);

    controller.handlePointerSignal(
      const PointerSignal(
        type: PointerSignalType.doubleTap,
        pointerId: 2,
        position: Offset(0, 0),
        timestampMs: 1,
        kind: PointerDeviceKind.touch,
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single.timestampMs, 1011);
  });

  test('double tap on overlapping texts picks top-most in same layer', () {
    final bottom = textNode('text-bottom', const Offset(0, 0));
    final top = textNode('text-top', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [bottom, top]),
      ],
    );
    final controller = SceneController(scene: scene);
    addTearDown(controller.dispose);

    final requests = <EditTextRequested>[];
    final sub = controller.editTextRequests.listen(requests.add);
    addTearDown(sub.cancel);

    controller.handlePointerSignal(
      const PointerSignal(
        type: PointerSignalType.doubleTap,
        pointerId: 3,
        position: Offset(0, 0),
        timestampMs: 200,
        kind: PointerDeviceKind.touch,
      ),
    );

    expect(requests, hasLength(1));
    expect(requests.single.nodeId, 'text-top');
  });
}
