import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/input/slices/signals/action_dispatcher.dart';
import 'package:iwb_canvas_engine/src/input/action_events.dart';

// INV:INV-SIGNALS-BROADCAST-SYNC
// INV:INV-SIGNALS-ACTIONID-FORMAT
// INV:INV-SIGNALS-DROP-AFTER-DISPOSE

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

  test('emit calls after dispose are safe and do not deliver events', () async {
    final dispatcher = ActionDispatcher();
    var actionEvents = 0;
    var editEvents = 0;

    final actionSub = dispatcher.actions.listen((_) => actionEvents++);
    final editSub = dispatcher.editTextRequests.listen((_) => editEvents++);
    addTearDown(actionSub.cancel);
    addTearDown(editSub.cancel);

    dispatcher.dispose();

    expect(
      () => dispatcher.emitAction(ActionType.transform, const <String>[], 0),
      returnsNormally,
    );
    expect(
      () => dispatcher.emitEditTextRequested(
        EditTextRequested(
          nodeId: 't1',
          timestampMs: 0,
          position: const Offset(1, 2),
        ),
      ),
      returnsNormally,
    );

    await Future<void>.delayed(Duration.zero);
    expect(actionEvents, 0);
    expect(editEvents, 0);
  });
}
