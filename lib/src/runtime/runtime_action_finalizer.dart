import '../contracts/internal/commit_action_intent.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_tools.dart';

final class RuntimeActionFinalizer {
  int _timestampCursor = -1;
  int _actionSequence = 0;

  List<CanvasActionCommitted> finalize(Iterable<CommitActionIntent> intents) {
    return List.unmodifiable(intents.map(_finalizeIntent));
  }

  int reserveTimestamp(int? hint) {
    return _resolveTimestamp(hint);
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
    DrawStrokeActionIntent(:final tool) => _drawStrokeActionType(tool),
    DrawLineActionIntent() => CanvasActionType.drawLine,
    EraseActionIntent() => CanvasActionType.erase,
    EditTextActionIntent() => CanvasActionType.editText,
  };
}

CanvasActionPayload _payload(CommitActionIntent intent) {
  return switch (intent) {
    MoveSelectionActionIntent() => _movePayload(intent),
    SelectMarqueeActionIntent() => _selectionPayload(intent),
    TransformSelectionActionIntent() => _transformPayload(intent),
    DeleteSelectionActionIntent(:final removedElementIds) ||
    RemoveElementActionIntent(
      :final removedElementIds,
    ) => _deletePayload(removedElementIds),
    ClearContentActionIntent() => _clearPayload(intent),
    DrawStrokeActionIntent() => _drawStrokePayload(intent),
    DrawLineActionIntent() => _drawLinePayload(intent),
    EraseActionIntent() => _erasePayload(intent),
    EditTextActionIntent() => _editTextPayload(intent),
  };
}

CanvasTransformActionPayload _movePayload(MoveSelectionActionIntent intent) {
  return CanvasTransformActionPayload(
    delta: intent.transform,
    operation: intent.operation,
    pivotWorld: intent.pivotWorld,
  );
}

CanvasSelectionActionPayload _selectionPayload(
  SelectMarqueeActionIntent intent,
) {
  return CanvasSelectionActionPayload(
    previousSelection: intent.previousSelection,
    nextSelection: intent.nextSelection,
    marqueeRectWorld: intent.marqueeRectWorld,
  );
}

CanvasTransformActionPayload _transformPayload(
  TransformSelectionActionIntent intent,
) {
  return CanvasTransformActionPayload(
    delta: intent.transform,
    operation: intent.operation,
    pivotWorld: intent.pivotWorld,
  );
}

CanvasDeleteActionPayload _deletePayload(
  Iterable<CanvasElementId> removedElementIds,
) {
  return CanvasDeleteActionPayload(removedElementIds: removedElementIds);
}

CanvasClearActionPayload _clearPayload(ClearContentActionIntent intent) {
  return CanvasClearActionPayload(
    removedElementIds: intent.removedElementIds,
    removedResourceIds: intent.removedResourceIds,
  );
}

CanvasActionType _drawStrokeActionType(CanvasDrawTool tool) {
  return switch (tool) {
    CanvasDrawTool.pencil => CanvasActionType.drawPencil,
    CanvasDrawTool.marker => CanvasActionType.drawMarker,
    CanvasDrawTool.line || CanvasDrawTool.eraser => throw StateError(
      'Unsupported draw stroke action tool: $tool',
    ),
  };
}

CanvasDrawStrokeActionPayload _drawStrokePayload(
  DrawStrokeActionIntent intent,
) {
  return CanvasDrawStrokeActionPayload(
    tool: intent.tool,
    color: intent.color,
    thickness: intent.thickness,
    opacity: intent.opacity,
    pointCount: intent.pointCount,
  );
}

CanvasDrawLineActionPayload _drawLinePayload(DrawLineActionIntent intent) {
  return CanvasDrawLineActionPayload(
    color: intent.color,
    thickness: intent.thickness,
    opacity: intent.opacity,
    startWorld: intent.startWorld,
    endWorld: intent.endWorld,
  );
}

CanvasEraseActionPayload _erasePayload(EraseActionIntent intent) {
  return CanvasEraseActionPayload(
    eraserThickness: intent.eraserThickness,
    erasedElementIds: intent.erasedElementIds,
    corridorPointCount: intent.corridorPointCount,
  );
}

CanvasTextEditActionPayload _editTextPayload(EditTextActionIntent intent) {
  return CanvasTextEditActionPayload(
    requestId: intent.requestId,
    previousTextLength: intent.previousTextLength,
    nextTextLength: intent.nextTextLength,
  );
}
