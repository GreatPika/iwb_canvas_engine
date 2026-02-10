import 'dart:ui';

import 'transform2d.dart';
import '../public/snapshot.dart';

/// Discrete actions emitted by interactive controllers for app-level undo/redo.
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

/// Request from the engine to edit a text node at [position].
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

  /// Parses layer move metadata from the action payload.
  ///
  /// Expected schema: `{sourceLayerIndex: int, targetLayerIndex: int}`.
  ({int sourceLayerIndex, int targetLayerIndex})? tryMoveLayerIndices() {
    final payload = this.payload;
    if (payload == null) return null;

    int? tryInt(Object? value) {
      if (value is int) return value;
      if (value is num) {
        final asInt = value.toInt();
        if (value == asInt) return asInt;
      }
      return null;
    }

    final source = tryInt(payload['sourceLayerIndex']);
    final target = tryInt(payload['targetLayerIndex']);
    if (source == null || target == null) return null;
    return (sourceLayerIndex: source, targetLayerIndex: target);
  }

  /// Parses common draw style metadata from the action payload.
  ///
  /// Expected schema: `{tool: String, color: int, thickness: double}`.
  ({String tool, int colorArgb, double thickness})? tryDrawStyle() {
    final payload = this.payload;
    if (payload == null) return null;

    int? tryInt(Object? value) {
      if (value is int) return value;
      if (value is num) {
        final asInt = value.toInt();
        if (value == asInt) return asInt;
      }
      return null;
    }

    double? tryDouble(Object? value) {
      if (value is num) return value.toDouble();
      return null;
    }

    final tool = payload['tool'];
    if (tool is! String) return null;
    final colorArgb = tryInt(payload['color']);
    final thickness = tryDouble(payload['thickness']);
    if (colorArgb == null || thickness == null) return null;
    return (tool: tool, colorArgb: colorArgb, thickness: thickness);
  }

  /// Parses eraser metadata from the action payload.
  ///
  /// Expected schema: `{eraserThickness: double}`.
  double? tryEraserThickness() {
    final payload = this.payload;
    if (payload == null) return null;
    final thickness = payload['eraserThickness'];
    if (thickness is num) return thickness.toDouble();
    return null;
  }
}
