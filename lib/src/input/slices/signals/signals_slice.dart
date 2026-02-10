import 'dart:async';

import 'signal_event.dart';

class V2SignalsSlice {
  final StreamController<V2CommittedSignal> _signals =
      StreamController<V2CommittedSignal>.broadcast(sync: true);

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

  int writeFlushBuffered({required int commitRevision}) {
    if (_isDisposed) return 0;
    final pending = _buffered;
    _buffered = const <V2BufferedSignal>[];
    var emitted = 0;

    for (final signal in pending) {
      if (_isDisposed) return emitted;
      _signals.add(
        V2CommittedSignal(
          signalId: 's${_signalCounter++}',
          type: signal.type,
          nodeIds: List.of(signal.nodeIds),
          payload: signal.payload,
          commitRevision: commitRevision,
        ),
      );
      emitted = emitted + 1;
    }
    return emitted;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _buffered = const <V2BufferedSignal>[];
    _signals.close();
  }
}
