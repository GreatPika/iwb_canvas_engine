import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/pointer_input.dart';

PointerSample _sample({
  required int id,
  required PointerPhase phase,
  required Offset position,
  required int t,
}) {
  return PointerSample(
    pointerId: id,
    phase: phase,
    position: position,
    timestampMs: t,
  );
}

void main() {
  test('emits base lifecycle signals for down/move/up/cancel', () {
    final tracker = PointerInputTracker();

    expect(
      tracker
          .handle(
            _sample(
              id: 1,
              phase: PointerPhase.down,
              position: const Offset(0, 0),
              t: 0,
            ),
          )
          .map((s) => s.type),
      contains(PointerSignalType.down),
    );
    expect(
      tracker
          .handle(
            _sample(
              id: 1,
              phase: PointerPhase.move,
              position: const Offset(1, 0),
              t: 1,
            ),
          )
          .map((s) => s.type),
      contains(PointerSignalType.move),
    );
    expect(
      tracker
          .handle(
            _sample(
              id: 1,
              phase: PointerPhase.up,
              position: const Offset(1, 0),
              t: 2,
            ),
          )
          .map((s) => s.type),
      contains(PointerSignalType.up),
    );
    expect(
      tracker
          .handle(
            _sample(
              id: 2,
              phase: PointerPhase.cancel,
              position: const Offset(0, 0),
              t: 3,
            ),
          )
          .map((s) => s.type),
      contains(PointerSignalType.cancel),
    );
  });

  test('move beyond tap slop prevents tap emission', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(tapSlop: 2, doubleTapMaxDelayMs: 10),
    );

    tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.down,
        position: const Offset(0, 0),
        t: 0,
      ),
    );
    tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.move,
        position: const Offset(10, 0),
        t: 1,
      ),
    );
    final upSignals = tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.up,
        position: const Offset(10, 0),
        t: 2,
      ),
    );

    expect(upSignals.any((s) => s.type == PointerSignalType.tap), isFalse);
    expect(tracker.hasPendingTap, isFalse);
  });

  test('deferred single tap is emitted on flush after timeout', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(
        doubleTapMaxDelayMs: 100,
        deferSingleTap: true,
      ),
    );

    tracker.handle(
      _sample(
        id: 7,
        phase: PointerPhase.down,
        position: const Offset(1, 1),
        t: 10,
      ),
    );
    final upSignals = tracker.handle(
      _sample(
        id: 7,
        phase: PointerPhase.up,
        position: const Offset(1, 1),
        t: 11,
      ),
    );

    expect(upSignals.any((s) => s.type == PointerSignalType.tap), isFalse);
    expect(tracker.hasPendingTap, isTrue);
    expect(tracker.nextPendingFlushTimestampMs, 112);

    expect(tracker.flushPending(111), isEmpty);
    final flushed = tracker.flushPending(200);
    expect(flushed.map((s) => s.type), contains(PointerSignalType.tap));
    expect(tracker.hasPendingTap, isFalse);
    expect(tracker.nextPendingFlushTimestampMs, isNull);
  });

  test('nextPendingFlushTimestampMs picks earliest pending tap', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(doubleTapMaxDelayMs: 100),
    );

    tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.down,
        position: const Offset(0, 0),
        t: 20,
      ),
    );
    tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.up,
        position: const Offset(0, 0),
        t: 20,
      ),
    );
    tracker.handle(
      _sample(
        id: 2,
        phase: PointerPhase.down,
        position: const Offset(0, 0),
        t: 10,
      ),
    );
    tracker.handle(
      _sample(
        id: 2,
        phase: PointerPhase.up,
        position: const Offset(0, 0),
        t: 10,
      ),
    );

    expect(tracker.nextPendingFlushTimestampMs, 111);
  });

  test('double tap is detected within distance/time window', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(
        doubleTapSlop: 20,
        doubleTapMaxDelayMs: 300,
        deferSingleTap: true,
      ),
    );

    tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.down,
        position: const Offset(10, 10),
        t: 0,
      ),
    );
    tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.up,
        position: const Offset(10, 10),
        t: 10,
      ),
    );

    tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.down,
        position: const Offset(12, 12),
        t: 40,
      ),
    );
    final secondUp = tracker.handle(
      _sample(
        id: 1,
        phase: PointerPhase.up,
        position: const Offset(12, 12),
        t: 50,
      ),
    );

    expect(secondUp.any((s) => s.type == PointerSignalType.doubleTap), isTrue);
    expect(secondUp.any((s) => s.type == PointerSignalType.tap), isFalse);
    expect(tracker.hasPendingTap, isFalse);
  });

  test('immediate tap mode emits tap on up and still tracks pending state', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(deferSingleTap: false),
    );

    tracker.handle(
      _sample(
        id: 9,
        phase: PointerPhase.down,
        position: const Offset(0, 0),
        t: 0,
      ),
    );
    final up = tracker.handle(
      _sample(
        id: 9,
        phase: PointerPhase.up,
        position: const Offset(0, 0),
        t: 1,
      ),
    );

    expect(up.any((s) => s.type == PointerSignalType.tap), isTrue);
    expect(tracker.hasPendingTap, isTrue);

    final flushed = tracker.flushPending(1000);
    expect(flushed, isEmpty);
    expect(tracker.hasPendingTap, isFalse);
  });

  test(
    'deferred mode emits prior single tap when second tap is not a double tap',
    () {
      final tracker = PointerInputTracker(
        settings: const PointerInputSettings(
          deferSingleTap: true,
          doubleTapMaxDelayMs: 300,
          doubleTapSlop: 5,
        ),
      );

      tracker.handle(
        _sample(
          id: 5,
          phase: PointerPhase.down,
          position: const Offset(0, 0),
          t: 0,
        ),
      );
      tracker.handle(
        _sample(
          id: 5,
          phase: PointerPhase.up,
          position: const Offset(0, 0),
          t: 1,
        ),
      );
      tracker.handle(
        _sample(
          id: 5,
          phase: PointerPhase.down,
          position: const Offset(100, 0),
          t: 2,
        ),
      );
      final signals = tracker.handle(
        _sample(
          id: 5,
          phase: PointerPhase.up,
          position: const Offset(100, 0),
          t: 3,
        ),
      );

      expect(signals.where((s) => s.type == PointerSignalType.tap).length, 1);
      expect(
        signals.any((s) => s.type == PointerSignalType.doubleTap),
        isFalse,
      );
      expect(tracker.hasPendingTap, isTrue);
    },
  );

  test('fromSample copies input sample fields', () {
    const sample = PointerSample(
      pointerId: 3,
      position: Offset(4, 5),
      timestampMs: 99,
      phase: PointerPhase.move,
      kind: PointerDeviceKind.mouse,
    );

    final signal = PointerSignal.fromSample(sample, PointerSignalType.move);
    expect(signal.pointerId, 3);
    expect(signal.position, const Offset(4, 5));
    expect(signal.timestampMs, 99);
    expect(signal.kind, PointerDeviceKind.mouse);
    expect(signal.type, PointerSignalType.move);
  });
}
