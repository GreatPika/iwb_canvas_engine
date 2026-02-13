import 'dart:async';

import 'signal_event.dart';

class V2SignalsSlice {
  final StreamController<V2CommittedSignal> _signals =
      StreamController<V2CommittedSignal>.broadcast();

  final List<V2BufferedSignal> _buffered = <V2BufferedSignal>[];
  int _signalCounter = 0;
  bool _isDisposed = false;

  Stream<V2CommittedSignal> get signals => _signals.stream;
  bool get writeHasBufferedSignals => _buffered.isNotEmpty;

  void writeBufferSignal(V2BufferedSignal signal) {
    if (_isDisposed) return;
    _buffered.add(signal);
  }

  void writeDiscardBuffered() {
    _buffered.clear();
  }

  List<V2CommittedSignal> writeTakeCommitted({required int commitRevision}) {
    if (_isDisposed) return const <V2CommittedSignal>[];
    if (_buffered.isEmpty) return const <V2CommittedSignal>[];
    final committed = List<V2CommittedSignal>.generate(_buffered.length, (
      index,
    ) {
      final signal = _buffered[index];
      return V2CommittedSignal(
        signalId: 's${_signalCounter++}',
        type: signal.type,
        nodeIds: signal.nodeIds,
        payload: signal.payload,
        commitRevision: commitRevision,
      );
    }, growable: false);
    _buffered.clear();
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
    _buffered.clear();
    _signals.close();
  }
}
