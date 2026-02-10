import 'dart:async';

import 'signal_event.dart';

class V2SignalsSlice {
  final StreamController<V2CommittedSignal> _signals =
      StreamController<V2CommittedSignal>.broadcast();

  List<V2BufferedSignal> _buffered = const <V2BufferedSignal>[];
  int _signalCounter = 0;
  bool _isDisposed = false;

  Stream<V2CommittedSignal> get signals => _signals.stream;
  bool get writeHasBufferedSignals => _buffered.isNotEmpty;

  void writeBufferSignal(V2BufferedSignal signal) {
    if (_isDisposed) return;
    _buffered = <V2BufferedSignal>[..._buffered, signal];
  }

  void writeDiscardBuffered() {
    _buffered = const <V2BufferedSignal>[];
  }

  List<V2CommittedSignal> writeTakeCommitted({required int commitRevision}) {
    if (_isDisposed) return const <V2CommittedSignal>[];
    final pending = _buffered;
    _buffered = const <V2BufferedSignal>[];
    if (pending.isEmpty) return const <V2CommittedSignal>[];
    final committed = <V2CommittedSignal>[];

    for (final signal in pending) {
      committed.add(
        V2CommittedSignal(
          signalId: 's${_signalCounter++}',
          type: signal.type,
          nodeIds: signal.nodeIds,
          payload: signal.payload,
          commitRevision: commitRevision,
        ),
      );
    }
    return committed;
  }

  void emitCommitted(Iterable<V2CommittedSignal> committed) {
    if (_isDisposed) return;
    for (final signal in committed) {
      if (_isDisposed) return;
      _signals.add(signal);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _buffered = const <V2BufferedSignal>[];
    _signals.close();
  }
}
