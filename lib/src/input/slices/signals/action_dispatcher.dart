import 'dart:async';

import '../../../core/nodes.dart';
import '../../action_events.dart';

/// Synchronous broadcast signals emitted by the input pipeline.
///
/// This slice is responsible for two streams:
/// - committed actions for app-level undo/redo integration
/// - requests to edit a text node
///
/// Invariants:
/// - controllers are `broadcast(sync: true)` to preserve delivery semantics
/// - action IDs keep the `a{counter++}` format
class ActionDispatcher {
  final StreamController<ActionCommitted> _actions =
      StreamController<ActionCommitted>.broadcast(sync: true);
  final StreamController<EditTextRequested> _editTextRequests =
      StreamController<EditTextRequested>.broadcast(sync: true);

  int _actionCounter = 0;

  Stream<ActionCommitted> get actions => _actions.stream;
  Stream<EditTextRequested> get editTextRequests => _editTextRequests.stream;

  void emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) {
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
    _editTextRequests.add(req);
  }

  void dispose() {
    _actions.close();
    _editTextRequests.close();
  }
}

