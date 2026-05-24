import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('removeElement and clearContent are not user action events', () async {
    final runtime = CanvasRuntime(initialDocument: _document());
    final actions = <CanvasActionCommitted>[];
    final subscription = runtime.actions.listen(actions.add);

    runtime.edits.edit((edit) {
      edit.removeElement(CanvasElementId('element-1'));
    });
    runtime.edits.edit((edit) {
      edit.clearContent();
    });
    await Future<void>.delayed(Duration.zero);

    expect(actions, isEmpty);
    await subscription.cancel();
    runtime.dispose();
  });
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('element-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
