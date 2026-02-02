import 'dart:ui';

import '../core/nodes.dart';
import '../core/transform2d.dart';

/// Discrete actions emitted by [SceneController] for app-level undo/redo.
enum ActionType {
  move,
  selectMarquee,
  transform,
  delete,
  clear,
  drawStroke,
  drawHighlighter,
  drawLine,
  erase,
}

/// A committed action with stable [actionId] and affected [nodeIds].
class ActionCommitted {
  const ActionCommitted({
    required this.actionId,
    required this.type,
    required this.nodeIds,
    required this.timestampMs,
    this.payload,
  });

  final String actionId;
  final ActionType type;
  final List<NodeId> nodeIds;
  final int timestampMs;
  final Map<String, Object?>? payload;
}

/// Request from the engine to edit a [TextNode] at [position].
class EditTextRequested {
  const EditTextRequested({
    required this.nodeId,
    required this.timestampMs,
    required this.position,
  });

  final NodeId nodeId;
  final int timestampMs;
  final Offset position;
}

extension ActionCommittedDelta on ActionCommitted {
  /// Parses `payload.delta` into a [Transform2D] when present and valid.
  ///
  /// Returns `null` if payload does not contain a valid delta map.
  Transform2D? tryTransformDelta() {
    final payload = this.payload;
    if (payload == null) return null;
    final delta = payload['delta'];
    if (delta is! Map) return null;

    final map = <String, Object?>{};
    for (final entry in delta.entries) {
      final key = entry.key;
      if (key is! String) return null;
      map[key] = entry.value;
    }

    try {
      return Transform2D.fromJsonMap(map);
    } on ArgumentError {
      return null;
    }
  }
}
