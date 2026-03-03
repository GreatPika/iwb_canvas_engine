import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signals_buffer.dart';

void main() {
  test('writeTakeCommitted preserves signal order and increments ids', () {
    final buffer = SignalsBuffer();
    addTearDown(buffer.dispose);

    buffer.writeBufferSignal(
      BufferedSignal(type: 'type-0', nodeIds: const <String>['n0']),
    );
    buffer.writeBufferSignal(
      BufferedSignal(type: 'type-1', nodeIds: const <String>['n1']),
    );
    buffer.writeBufferSignal(
      BufferedSignal(type: 'type-2', nodeIds: const <String>['n2']),
    );

    final committedA = buffer.writeTakeCommitted(commitRevision: 7);
    final committedB = buffer.writeTakeCommitted(commitRevision: 8);
    buffer.writeBufferSignal(
      BufferedSignal(type: 'type-3', nodeIds: const <String>['n3']),
    );
    final committedC = buffer.writeTakeCommitted(commitRevision: 9);

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
    expect(buffer.writeHasBufferedSignals, isFalse);
  });

  test('writeDiscardBuffered clears pending signals', () {
    final buffer = SignalsBuffer();
    addTearDown(buffer.dispose);

    buffer.writeBufferSignal(
      BufferedSignal(type: 'type-0', nodeIds: const <String>[]),
    );
    expect(buffer.writeHasBufferedSignals, isTrue);

    buffer.writeDiscardBuffered();
    expect(buffer.writeHasBufferedSignals, isFalse);
    expect(buffer.writeTakeCommitted(commitRevision: 1), isEmpty);
  });

  test('writeTakeCommitted handles large batches with stable ordering', () {
    final buffer = SignalsBuffer();
    addTearDown(buffer.dispose);
    const totalSignals = 10000;

    for (var i = 0; i < totalSignals; i++) {
      buffer.writeBufferSignal(
        BufferedSignal(type: 'type-$i', nodeIds: const <String>[]),
      );
    }

    final committed = buffer.writeTakeCommitted(commitRevision: 42);

    expect(committed, hasLength(totalSignals));
    for (var i = 0; i < totalSignals; i++) {
      expect(committed[i].type, 'type-$i');
      expect(committed[i].signalId, 's$i');
      expect(committed[i].commitRevision, 42);
    }
    expect(buffer.writeHasBufferedSignals, isFalse);
  });
}
