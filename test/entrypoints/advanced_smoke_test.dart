import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('advanced.dart exports SceneController and input types', () {
    final controller = SceneController();
    addTearDown(controller.dispose);

    expect(controller.mode, CanvasMode.move);
    controller.setMode(CanvasMode.draw);
    expect(controller.mode, CanvasMode.draw);

    expect(controller.drawTool, DrawTool.pen);
    controller.setDrawTool(DrawTool.line);
    expect(controller.drawTool, DrawTool.line);
  });
}
