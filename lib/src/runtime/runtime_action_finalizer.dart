import '../contracts/internal/commit_action_intent.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_ids.dart';

final class RuntimeActionFinalizer {
  int _timestampCursor = -1;
  int _actionSequence = 0;

  List<CanvasActionCommitted> finalize(Iterable<CommitActionIntent> intents) {
    return List.unmodifiable(intents.map(_finalizeIntent));
  }

  CanvasActionCommitted _finalizeIntent(CommitActionIntent intent) {
    return CanvasActionCommitted(
      actionId: _nextActionId(),
      type: _actionType(intent),
      elementIds: intent.elementIds,
      timestampMs: _resolveTimestamp(intent.timestampHintMs),
      payload: _payload(intent),
    );
  }

  CanvasActionId _nextActionId() {
    final id = CanvasActionId('action-$_actionSequence');
    _actionSequence += 1;

    return id;
  }

  int _resolveTimestamp(int? hint) {
    final next = _timestampCursor + 1;
    final resolved = hint != null && hint >= next ? hint : next;
    _timestampCursor = resolved;

    return resolved;
  }
}

CanvasActionType _actionType(CommitActionIntent intent) {
  return switch (intent) {
    MoveSelectionActionIntent() => CanvasActionType.moveSelection,
    SelectMarqueeActionIntent() => CanvasActionType.selectMarquee,
    TransformSelectionActionIntent() => CanvasActionType.transformSelection,
    DeleteSelectionActionIntent() ||
    RemoveElementActionIntent() => CanvasActionType.deleteElements,
    ClearContentActionIntent() => CanvasActionType.clearContent,
  };
}

CanvasActionPayload _payload(CommitActionIntent intent) {
  return switch (intent) {
    MoveSelectionActionIntent(:final transform) => CanvasTransformActionPayload(
      delta: transform,
      operation: intent.operation,
      pivotWorld: intent.pivotWorld,
    ),
    SelectMarqueeActionIntent(
      :final previousSelection,
      :final nextSelection,
      :final marqueeRectWorld,
    ) =>
      CanvasSelectionActionPayload(
        previousSelection: previousSelection,
        nextSelection: nextSelection,
        marqueeRectWorld: marqueeRectWorld,
      ),
    TransformSelectionActionIntent(
      :final transform,
      :final operation,
      :final pivotWorld,
    ) =>
      CanvasTransformActionPayload(
        delta: transform,
        operation: operation,
        pivotWorld: pivotWorld,
      ),
    DeleteSelectionActionIntent(:final removedElementIds) =>
      CanvasDeleteActionPayload(removedElementIds: removedElementIds),
    RemoveElementActionIntent(:final removedElementIds) =>
      CanvasDeleteActionPayload(removedElementIds: removedElementIds),
    ClearContentActionIntent(
      :final removedElementIds,
      :final removedResourceIds,
    ) =>
      CanvasClearActionPayload(
        removedElementIds: removedElementIds,
        removedResourceIds: removedResourceIds,
      ),
  };
}
