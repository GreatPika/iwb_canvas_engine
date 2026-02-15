import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signals_buffer.dart';

void main() {
  test('writeTakeCommitted preserves signal order and increments ids', () {
    final slice = SignalsBuffer();
    addTearDown(slice.dispose);

    slice.writeBufferSignal(
      BufferedSignal(type: 'type-0', nodeIds: const <String>['n0']),
    );
    slice.writeBufferSignal(
      BufferedSignal(type: 'type-1', nodeIds: const <String>['n1']),
    );
    slice.writeBufferSignal(
      BufferedSignal(type: 'type-2', nodeIds: const <String>['n2']),
    );

    final committedA = slice.writeTakeCommitted(commitRevision: 7);
    final committedB = slice.writeTakeCommitted(commitRevision: 8);
    slice.writeBufferSignal(
      BufferedSignal(type: 'type-3', nodeIds: const <String>['n3']),
    );
    final committedC = slice.writeTakeCommitted(commitRevision: 9);

    expect(
      committedA.map((signal) => signal.type).toList(growable: false),
      const <String>['type-0', 'type-1', 'type-2'],
    );
    expect(
      committedA.map((signal) => signal.signalId).toList(growable: false),
      const <String>['s0', 's1', 's2'],
    );
    expect(
      committedA.map((signal) => signal.commitRevision).toList(growable: false),
      const <int>[7, 7, 7],
    );
    expect(committedB, isEmpty);
    expect(committedC.single.signalId, 's3');
    expect(committedC.single.commitRevision, 9);
    expect(slice.writeHasBufferedSignals, isFalse);
  });

  test('writeDiscardBuffered clears pending signals', () {
    final slice = SignalsBuffer();
    addTearDown(slice.dispose);

    slice.writeBufferSignal(
      BufferedSignal(type: 'type-0', nodeIds: const <String>[]),
    );
    expect(slice.writeHasBufferedSignals, isTrue);

    slice.writeDiscardBuffered();
    expect(slice.writeHasBufferedSignals, isFalse);
    expect(slice.writeTakeCommitted(commitRevision: 1), isEmpty);
  });

  test('writeTakeCommitted handles large batches with stable ordering', () {
    final slice = SignalsBuffer();
    addTearDown(slice.dispose);
    const totalSignals = 10000;

    for (var i = 0; i < totalSignals; i++) {
      slice.writeBufferSignal(
        BufferedSignal(type: 'type-$i', nodeIds: const <String>[]),
      );
    }

    final committed = slice.writeTakeCommitted(commitRevision: 42);

    expect(committed, hasLength(totalSignals));
    for (var i = 0; i < totalSignals; i++) {
      expect(committed[i].type, 'type-$i');
      expect(committed[i].signalId, 's$i');
      expect(committed[i].commitRevision, 42);
    }
    expect(slice.writeHasBufferedSignals, isFalse);
  });
}
