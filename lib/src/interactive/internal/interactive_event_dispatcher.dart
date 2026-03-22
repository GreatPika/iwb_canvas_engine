import 'dart:async';

import 'package:flutter/foundation.dart';

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

class InteractiveNotifyScheduler {
  InteractiveNotifyScheduler({required this.notifyListeners});

  final VoidCallback notifyListeners;

  bool _notifyScheduled = false;
  bool _notifyPending = false;
  bool _isDisposed = false;

  void schedule() {
    if (_isDisposed) {
      return;
    }
    _notifyPending = true;
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;

    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_isDisposed || !_notifyPending) {
        return;
      }
      _notifyPending = false;
      notifyListeners();
    });
  }

  void dispose() {
    _isDisposed = true;
    _notifyPending = false;
    _notifyScheduled = false;
  }
}
