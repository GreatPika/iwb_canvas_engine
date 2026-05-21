import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('projection cache is touched only by explicit readDocument', () {
    final root = RuntimeRoot(
      initialDocument: CanvasDocument(
        layers: [CanvasLayer(id: CanvasLayerId('layer-a'))],
      ),
      config: const CanvasRuntimeConfig(),
    );

    expect(root.projectionBuildCount, 0);
    expect(root.state.value.summary.layerCount, 1);
    expect(root.generateElementId(), CanvasElementId('e0'));
    expect(root.generateLayerId(), CanvasLayerId('l0'));
    expect(root.generateResourceId(), CanvasResourceId('r0'));
    expect(root.projectionBuildCount, 0);

    root.readDocument();
    expect(root.projectionBuildCount, 1);
    root.readDocument();
    expect(root.projectionBuildCount, 1);

    root.dispose();
  });
}
