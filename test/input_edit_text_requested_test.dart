import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
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
}
