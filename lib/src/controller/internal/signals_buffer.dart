import 'dart:async';

import 'signal_event.dart';

class SignalsBuffer {
  final StreamController<CommittedSignal> _signals =
      StreamController<CommittedSignal>.broadcast();

  final List<BufferedSignal> _buffered = <BufferedSignal>[];
  int _signalCounter = 0;
  bool _isDisposed = false;

  Stream<CommittedSignal> get signals => _signals.stream;
  bool get writeHasBufferedSignals => _buffered.isNotEmpty;

  void writeBufferSignal(BufferedSignal signal) {
    if (_isDisposed) return;
    _buffered.add(signal);
  }

  void writeDiscardBuffered() {
    _buffered.clear();
  }

  List<CommittedSignal> writeTakeCommitted({required int commitRevision}) {
    if (_isDisposed) return const <CommittedSignal>[];
    if (_buffered.isEmpty) return const <CommittedSignal>[];
    final committed = List<CommittedSignal>.generate(_buffered.length, (index) {
      final signal = _buffered[index];
      return CommittedSignal(
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

  void emitCommitted(Iterable<CommittedSignal> committed) {
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
