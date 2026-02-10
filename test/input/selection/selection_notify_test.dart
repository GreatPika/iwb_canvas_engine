import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';

// INV:INV-SELECTION-SETSELECTION-COALESCED
// INV:INV-SELECTION-UNORDERED-SET

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

  testWidgets('setSelection treats ordering as irrelevant', (tester) async {
    final first = RectNode(
      id: 'a',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final second = RectNode(
      id: 'b',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(20, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [first, second]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.setSelection(const <NodeId>{'a', 'b'});
    await tester.pump();
    final revisionAfterFirstSet = controller.debugSelectionRevision;

    controller.setSelection(const <NodeId>{'b', 'a'});
    await tester.pump();

    expect(controller.selectedNodeIds, const <NodeId>{'a', 'b'});
    expect(controller.debugSelectionRevision, revisionAfterFirstSet);
  });
}
