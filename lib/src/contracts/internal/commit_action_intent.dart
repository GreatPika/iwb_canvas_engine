import 'dart:ui';

import '../public/canvas_actions.dart';
import '../public/canvas_geometry.dart';
import '../public/canvas_ids.dart';
import '../public/canvas_value_validators.dart';

enum CommitActionIntentKind {
  moveSelection,
  selectMarquee,
  transformSelection,
  deleteSelection,
  removeElement,
  clearContent,
}

sealed class CommitActionIntent {
  CommitActionIntent({int? timestampHintMs})
    : timestampHintMs = _validateTimestampHint(timestampHintMs);

  CommitActionIntentKind get kind;
  List<CanvasElementId> get elementIds;
  final int? timestampHintMs;
}

final class MoveSelectionActionIntent extends CommitActionIntent {
  MoveSelectionActionIntent({
    required Iterable<CanvasElementId> elementIds,
    required this.transform,
    super.timestampHintMs,
  }) : elementIds = List.unmodifiable(elementIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.moveSelection;

  @override
  final List<CanvasElementId> elementIds;
  final CanvasTransform transform;
  CanvasTransformOperation get operation => CanvasTransformOperation.move;
  Offset? get pivotWorld => null;
}

final class SelectMarqueeActionIntent extends CommitActionIntent {
  SelectMarqueeActionIntent({
    required Iterable<CanvasElementId> previousSelection,
    required Iterable<CanvasElementId> nextSelection,
    required this.marqueeRectWorld,
    super.timestampHintMs,
  }) : previousSelection = List.unmodifiable(previousSelection),
       nextSelection = List.unmodifiable(nextSelection);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.selectMarquee;

  @override
  List<CanvasElementId> get elementIds => nextSelection;

  final List<CanvasElementId> previousSelection;
  final List<CanvasElementId> nextSelection;
  final Rect marqueeRectWorld;
}

final class TransformSelectionActionIntent extends CommitActionIntent {
  TransformSelectionActionIntent({
    required Iterable<CanvasElementId> elementIds,
    required this.transform,
    required this.operation,
    required this.pivotWorld,
    super.timestampHintMs,
  }) : elementIds = List.unmodifiable(elementIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.transformSelection;

  @override
  final List<CanvasElementId> elementIds;
  final CanvasTransform transform;
  final CanvasTransformOperation operation;
  final Offset pivotWorld;
}

final class DeleteSelectionActionIntent extends CommitActionIntent {
  DeleteSelectionActionIntent({
    required Iterable<CanvasElementId> removedElementIds,
    super.timestampHintMs,
  }) : removedElementIds = List.unmodifiable(removedElementIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.deleteSelection;

  @override
  List<CanvasElementId> get elementIds => removedElementIds;

  final List<CanvasElementId> removedElementIds;
}

final class RemoveElementActionIntent extends CommitActionIntent {
  RemoveElementActionIntent({
    required CanvasElementId elementId,
    super.timestampHintMs,
  }) : removedElementIds = List.unmodifiable([elementId]);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.removeElement;

  @override
  List<CanvasElementId> get elementIds => removedElementIds;

  final List<CanvasElementId> removedElementIds;
}

final class ClearContentActionIntent extends CommitActionIntent {
  ClearContentActionIntent({
    required Iterable<CanvasElementId> removedElementIds,
    required Iterable<CanvasResourceId> removedResourceIds,
    super.timestampHintMs,
  }) : removedElementIds = List.unmodifiable(removedElementIds),
       removedResourceIds = List.unmodifiable(removedResourceIds);

  @override
  CommitActionIntentKind get kind => CommitActionIntentKind.clearContent;

  @override
  List<CanvasElementId> get elementIds => removedElementIds;

  final List<CanvasElementId> removedElementIds;
  final List<CanvasResourceId> removedResourceIds;
}

int? _validateTimestampHint(int? timestampHintMs) {
  if (timestampHintMs != null) {
    validateNonNegativeInt(timestampHintMs, path: 'action.timestampMs');
  }

  return timestampHintMs;
}
