import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'public pointer input constructors enforce boundary invariants',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName: 'iwb_canvas_engine_pointer_input_consumer',
          testFileName: 'pointer_input_test.dart',
          testSource: _pointerInputTestSource,
        ),
        completes,
      );
    },
  );
}

const _pointerInputTestSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('finite samples remain finite-only for every lifecycle phase', () {
    for (final phase in CanvasPointerLifecyclePhase.values) {
      final sample = CanvasPointerSample(
        pointerId: 1,
        position: const Offset(4, 5),
        phase: phase,
        kind: PointerDeviceKind.touch,
        timestampMs: 10,
      );

      expect(sample, isA<CanvasPointerInput>());
      expect(sample.position, const Offset(4, 5));
      expect(sample.phase, phase);
    }

    for (final phase in CanvasPointerLifecyclePhase.values) {
      expect(
        () => CanvasPointerSample(
          pointerId: 1,
          position: const Offset(double.nan, 0),
          phase: phase,
          kind: PointerDeviceKind.touch,
        ),
        throwsA(
          isA<CanvasDataException>()
              .having(
                (error) => error.code,
                'code',
                CanvasDataErrorCode.fieldMustBeFinite,
              )
              .having((error) => error.path, 'path', 'pointer.position.dx'),
        ),
      );
    }
  });

  test('terminal cleanup accepts only terminal phases without coordinates', () {
    final up = CanvasPointerTerminalCleanup(
      pointerId: 7,
      phase: CanvasPointerLifecyclePhase.up,
      kind: PointerDeviceKind.mouse,
      timestampMs: 12,
    );
    final cancel = CanvasPointerTerminalCleanup(
      pointerId: 8,
      phase: CanvasPointerLifecyclePhase.cancel,
      kind: PointerDeviceKind.stylus,
    );

    expect(up, isA<CanvasPointerInput>());
    expect(up.pointerId, 7);
    expect(up.phase, CanvasPointerLifecyclePhase.up);
    expect(up.kind, PointerDeviceKind.mouse);
    expect(up.timestampMs, 12);
    expect(cancel.phase, CanvasPointerLifecyclePhase.cancel);
    expect(cancel.timestampMs, isNull);

    for (final phase in [
      CanvasPointerLifecyclePhase.down,
      CanvasPointerLifecyclePhase.move,
    ]) {
      expect(
        () => CanvasPointerTerminalCleanup(
          pointerId: 1,
          phase: phase,
          kind: PointerDeviceKind.touch,
        ),
        throwsA(
          isA<CanvasDataException>()
              .having(
                (error) => error.code,
                'code',
                CanvasDataErrorCode.fieldMustBeInRange,
              )
              .having((error) => error.path, 'path', 'pointer.phase'),
        ),
      );
    }
  });

  test('terminal cleanup validates public scalar fields', () {
    expect(
      () => CanvasPointerTerminalCleanup(
        pointerId: -1,
        phase: CanvasPointerLifecyclePhase.up,
        kind: PointerDeviceKind.touch,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMustBeNonNegative,
            )
            .having((error) => error.path, 'path', 'pointer.pointerId'),
      ),
    );
    expect(
      () => CanvasPointerTerminalCleanup(
        pointerId: 1,
        phase: CanvasPointerLifecyclePhase.cancel,
        kind: PointerDeviceKind.touch,
        timestampMs: -1,
      ),
      throwsA(
        isA<CanvasDataException>()
            .having(
              (error) => error.code,
              'code',
              CanvasDataErrorCode.fieldMustBeNonNegative,
            )
            .having((error) => error.path, 'path', 'pointer.timestampMs'),
      ),
    );
  });
}
''';
