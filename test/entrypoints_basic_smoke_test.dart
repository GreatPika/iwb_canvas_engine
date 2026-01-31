import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart';

void main() {
  testWidgets('basic.dart supports a minimal happy-path integration', (
    tester,
  ) async {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            RectNode(
              id: 'rect-1',
              size: const Size(60, 40),
              fillColor: const Color(0xFF2196F3),
            )..position = const Offset(100, 100),
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
          width: 200,
          height: 200,
          child: SceneView(controller: controller, imageResolver: (_) => null),
        ),
      ),
    );

    expect(controller.selectedNodeIds, isEmpty);

    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.selectedNodeIds, contains('rect-1'));
  });
}
