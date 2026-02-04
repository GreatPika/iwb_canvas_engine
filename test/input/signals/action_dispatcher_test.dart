import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/input/slices/signals/action_dispatcher.dart';
import 'package:iwb_canvas_engine/src/input/action_events.dart';

// INV:INV-SIGNALS-BROADCAST-SYNC
// INV:INV-SIGNALS-ACTIONID-FORMAT

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('streams deliver events synchronously', () {
    final dispatcher = ActionDispatcher();
    addTearDown(dispatcher.dispose);

    var gotAction = false;
    dispatcher.actions.listen((_) => gotAction = true);

    var gotEditRequest = false;
    dispatcher.editTextRequests.listen((_) => gotEditRequest = true);

    dispatcher.emitAction(ActionType.transform, const <String>[], 0);
    dispatcher.emitEditTextRequested(
      EditTextRequested(
        nodeId: 't1',
        timestampMs: 0,
        position: const Offset(1, 2),
      ),
    );

    expect(gotAction, isTrue);
    expect(gotEditRequest, isTrue);
  });

  test('actionId format stays a{counter++}', () async {
    final dispatcher = ActionDispatcher();
    addTearDown(dispatcher.dispose);

    final ids = <String>[];
    final sub = dispatcher.actions.listen((a) => ids.add(a.actionId));
    addTearDown(sub.cancel);

    dispatcher.emitAction(ActionType.transform, const <String>[], 0);
    dispatcher.emitAction(ActionType.transform, const <String>[], 0);
    dispatcher.emitAction(ActionType.transform, const <String>[], 0);

    expect(ids, ['a0', 'a1', 'a2']);
  });
}
