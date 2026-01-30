import 'package:flutter_test/flutter_test.dart';

import 'package:iwb_canvas_engine/input/pointer_input.dart';

void main() {
  test('emits down move up then deferred tap', () {
    final tracker = PointerInputTracker();

    final signals = <PointerSignal>[
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(12, 12),
          timestampMs: 8,
          phase: PointerPhase.move,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(12, 12),
          timestampMs: 16,
          phase: PointerPhase.up,
        ),
      ),
      ...tracker.flushPending(500),
    ];

    expect(signals.map((signal) => signal.type).toList(), <PointerSignalType>[
      PointerSignalType.down,
      PointerSignalType.move,
      PointerSignalType.up,
      PointerSignalType.tap,
    ]);
  });

  test('cancel clears pointer down state and emits cancel signal', () {
    final tracker = PointerInputTracker();

    final signals = <PointerSignal>[
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(0, 0),
          timestampMs: 1,
          phase: PointerPhase.cancel,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(0, 0),
          timestampMs: 2,
          phase: PointerPhase.up,
        ),
      ),
      ...tracker.flushPending(500),
    ];

    expect(signals.map((signal) => signal.type).toList(), <PointerSignalType>[
      PointerSignalType.down,
      PointerSignalType.cancel,
      PointerSignalType.up,
    ]);
  });

  test('emits double tap within thresholds', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(
        tapSlop: 8,
        doubleTapSlop: 24,
        doubleTapMaxDelayMs: 300,
      ),
    );

    final signals = <PointerSignal>[
      ...tracker.handle(
        PointerSample(
          pointerId: 7,
          position: const Offset(20, 20),
          timestampMs: 100,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 7,
          position: const Offset(20, 20),
          timestampMs: 160,
          phase: PointerPhase.up,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 8,
          position: const Offset(25, 22),
          timestampMs: 240,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 8,
          position: const Offset(25, 22),
          timestampMs: 280,
          phase: PointerPhase.up,
        ),
      ),
      ...tracker.flushPending(800),
    ];

    expect(signals.map((signal) => signal.type).toList(), <PointerSignalType>[
      PointerSignalType.down,
      PointerSignalType.up,
      PointerSignalType.down,
      PointerSignalType.up,
      PointerSignalType.doubleTap,
    ]);
  });

  test('deferSingleTap=false emits tap immediately on up', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(deferSingleTap: false),
    );

    final signals = <PointerSignal>[
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: PointerPhase.up,
        ),
      ),
    ];

    expect(signals.map((signal) => signal.type).toList(), <PointerSignalType>[
      PointerSignalType.down,
      PointerSignalType.up,
      PointerSignalType.tap,
    ]);
  });

  test('second tap within window but far away emits pending tap', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(
        doubleTapMaxDelayMs: 300,
        doubleTapSlop: 1,
      ),
    );

    final signals = <PointerSignal>[
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(0, 0),
          timestampMs: 10,
          phase: PointerPhase.up,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 100,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 110,
          phase: PointerPhase.up,
        ),
      ),
    ];

    expect(
      signals.map((signal) => signal.type),
      contains(PointerSignalType.tap),
    );
    expect(
      signals.map((signal) => signal.type),
      isNot(contains(PointerSignalType.doubleTap)),
    );
  });

  test('flushPending ignores negative time deltas', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(doubleTapMaxDelayMs: 100),
    );

    tracker.handle(
      PointerSample(
        pointerId: 1,
        position: const Offset(10, 10),
        timestampMs: 100,
        phase: PointerPhase.down,
      ),
    );
    tracker.handle(
      PointerSample(
        pointerId: 1,
        position: const Offset(10, 10),
        timestampMs: 110,
        phase: PointerPhase.up,
      ),
    );

    expect(tracker.flushPending(50), isEmpty);
    expect(
      tracker.flushPending(1000).map((s) => s.type),
      contains(PointerSignalType.tap),
    );
  });

  test('drag beyond tap slop does not emit tap', () {
    final tracker = PointerInputTracker(
      settings: const PointerInputSettings(tapSlop: 4),
    );

    final signals = <PointerSignal>[
      ...tracker.handle(
        PointerSample(
          pointerId: 3,
          position: const Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 3,
          position: const Offset(10, 0),
          timestampMs: 10,
          phase: PointerPhase.move,
        ),
      ),
      ...tracker.handle(
        PointerSample(
          pointerId: 3,
          position: const Offset(12, 0),
          timestampMs: 20,
          phase: PointerPhase.up,
        ),
      ),
      ...tracker.flushPending(500),
    ];

    expect(signals.map((signal) => signal.type).toList(), <PointerSignalType>[
      PointerSignalType.down,
      PointerSignalType.move,
      PointerSignalType.up,
    ]);
  });
}
