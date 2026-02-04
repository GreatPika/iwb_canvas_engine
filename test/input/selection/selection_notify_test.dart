import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

// INV:INV-SELECTION-SETSELECTION-COALESCED

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setSelection is coalesced (not immediate notify)', (
    tester,
  ) async {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.setSelection(const <String>['r1']);

    expect(notifications, 0);
    await tester.pump();
    expect(notifications, 1);
  });
}
