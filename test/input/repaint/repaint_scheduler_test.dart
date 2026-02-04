import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/input/slices/repaint/repaint_scheduler.dart';

// INV:INV-REPAINT-ONE-PER-FRAME
// INV:INV-REPAINT-TOKEN-CANCELS
// INV:INV-REPAINT-NOTIFYNOW-CLEARS

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('requestRepaintOncePerFrame schedules at most one frame', (
    tester,
  ) async {
    var calls = 0;
    final scheduler = RepaintScheduler(notifyListeners: () => calls++);
    addTearDown(scheduler.dispose);

    scheduler.requestRepaintOncePerFrame();
    scheduler.requestRepaintOncePerFrame();
    scheduler.requestRepaintOncePerFrame();

    expect(calls, 0);
    await tester.pump();
    expect(calls, 1);

    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('notifyNow cancels scheduled repaint and clears needsNotify', (
    tester,
  ) async {
    var calls = 0;
    final scheduler = RepaintScheduler(notifyListeners: () => calls++);
    addTearDown(scheduler.dispose);

    scheduler.markNeedsNotify();
    expect(scheduler.needsNotify, isTrue);

    scheduler.requestRepaintOncePerFrame();
    expect(calls, 0);

    scheduler.notifyNow();
    expect(calls, 1);
    expect(scheduler.needsNotify, isFalse);

    await tester.pump();
    expect(calls, 1);
  });
}
