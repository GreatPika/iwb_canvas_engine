import 'dart:async';

import '../../core/action_events.dart';
import '../../contract/snapshot.dart';

class InteractiveEventDispatcher {
  final StreamController<ActionCommitted> _actions =
      StreamController<ActionCommitted>.broadcast();
  final StreamController<EditTextRequested> _editTextRequests =
      StreamController<EditTextRequested>.broadcast();

  int _actionCounter = 0;
  bool _isDisposed = false;

  Stream<ActionCommitted> get actions => _actions.stream;
  Stream<EditTextRequested> get editTextRequests => _editTextRequests.stream;

  void emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) {
    if (_isDisposed) return;
    _actions.add(
      ActionCommitted(
        actionId: 'a${_actionCounter++}',
        type: type,
        nodeIds: List<NodeId>.from(nodeIds),
        timestampMs: timestampMs,
        payload: payload,
      ),
    );
  }

  void emitEditTextRequested(EditTextRequested req) {
    if (_isDisposed) return;
    _editTextRequests.add(req);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _actions.close();
    _editTextRequests.close();
  }
}
