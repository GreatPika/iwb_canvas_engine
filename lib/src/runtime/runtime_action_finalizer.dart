import 'dart:async';

import 'package:meta/meta.dart' show immutable, visibleForTesting;

import '../contracts/internal/commit_action_intent.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_tools.dart';

@visibleForTesting
enum DeletionActionElementReadPhase { committedAction, payload }

@immutable
@visibleForTesting
final class DeletionActionElementReadEvent {
  const DeletionActionElementReadEvent(this.phase);

  final DeletionActionElementReadPhase phase;
}

final class RuntimeActionFinalizer {
  static final Object _deletionElementReadZoneKey = Object();
  int _timestampCursor = -1;
  int _actionSequence = 0;

  /// Observes only the real deletion-ID copies performed by action finalizing.
  /// The lazy wrapper is created behind assertions, leaving release values and
  /// their iteration unchanged.
  @visibleForTesting
  static T observeDeletionElementIdReads<T>(
    void Function(DeletionActionElementReadEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_deletionElementReadZoneKey: sink});

  List<CanvasActionCommitted> finalize(Iterable<CommitActionIntent> intents) {
    return List.unmodifiable(intents.map(_finalizeIntent));
  }

  int reserveTimestamp(int? hint) {
    return _resolveTimestamp(hint);
  }

  CanvasActionCommitted _finalizeIntent(CommitActionIntent intent) {
    Iterable<CanvasElementId> observedElementIds = intent.elementIds;
    assert(() {
      if (intent is DeleteSelectionActionIntent ||
          intent is EraseActionIntent) {
        observedElementIds = _observeDeletionElementIds(
          observedElementIds,
          DeletionActionElementReadPhase.committedAction,
        );
      }
      return true;
    }(), 'deletion action element read observation failed');
    return CanvasActionCommitted(
      actionId: _nextActionId(),
      type: _actionType(intent),
      elementIds: observedElementIds,
      timestampMs: _resolveTimestamp(intent.timestampHintMs),
      payload: _payload(intent),
    );
  }

  static Iterable<CanvasElementId> _observeDeletionElementIds(
    Iterable<CanvasElementId> ids,
    DeletionActionElementReadPhase phase,
  ) {
    final sink = Zone.current[_deletionElementReadZoneKey];
    if (sink is! void Function(DeletionActionElementReadEvent)) {
      return ids;
    }
    return _ObservedDeletionElementIds(ids, () {
      sink(DeletionActionElementReadEvent(phase));
    });
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
  switch (intent) {
    case MoveSelectionActionIntent():
      return _movePayload(intent);
    case SelectMarqueeActionIntent():
      return _selectionPayload(intent);
    case TransformSelectionActionIntent():
      return _transformPayload(intent);
    case DeleteSelectionActionIntent(:final removedElementIds):
      Iterable<CanvasElementId> observedElementIds = removedElementIds;
      assert(() {
        observedElementIds = RuntimeActionFinalizer._observeDeletionElementIds(
          observedElementIds,
          DeletionActionElementReadPhase.payload,
        );
        return true;
      }(), 'deletion action element read observation failed');
      return _deletePayload(observedElementIds);
    case RemoveElementActionIntent(:final removedElementIds):
      return _deletePayload(removedElementIds);
    case ClearContentActionIntent():
      return _clearPayload(intent);
    case DrawStrokeActionIntent():
      return _drawStrokePayload(intent);
    case DrawLineActionIntent():
      return _drawLinePayload(intent);
    case EraseActionIntent(:final erasedElementIds):
      Iterable<CanvasElementId> observedElementIds = erasedElementIds;
      assert(() {
        observedElementIds = RuntimeActionFinalizer._observeDeletionElementIds(
          observedElementIds,
          DeletionActionElementReadPhase.payload,
        );
        return true;
      }(), 'deletion action element read observation failed');
      return _erasePayload(intent, observedElementIds);
    case EditTextActionIntent():
      return _editTextPayload(intent);
  }
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

CanvasEraseActionPayload _erasePayload(
  EraseActionIntent intent,
  Iterable<CanvasElementId> erasedElementIds,
) {
  return CanvasEraseActionPayload(
    eraserThickness: intent.eraserThickness,
    erasedElementIds: erasedElementIds,
    corridorPointCount: intent.corridorPointCount,
  );
}

final class _ObservedDeletionElementIds extends Iterable<CanvasElementId> {
  _ObservedDeletionElementIds(this._delegate, this._onRead);

  final Iterable<CanvasElementId> _delegate;
  final void Function() _onRead;

  @override
  Iterator<CanvasElementId> get iterator =>
      _ObservedDeletionElementIterator(_delegate.iterator, _onRead);
}

final class _ObservedDeletionElementIterator
    implements Iterator<CanvasElementId> {
  _ObservedDeletionElementIterator(this._delegate, this._onRead);

  final Iterator<CanvasElementId> _delegate;
  final void Function() _onRead;

  @override
  CanvasElementId get current => _delegate.current;

  @override
  bool moveNext() {
    final hasElement = _delegate.moveNext();
    if (hasElement) {
      _onRead();
    }
    return hasElement;
  }
}

CanvasTextEditActionPayload _editTextPayload(EditTextActionIntent intent) {
  return CanvasTextEditActionPayload(
    requestId: intent.requestId,
    previousTextLength: intent.previousTextLength,
    nextTextLength: intent.nextTextLength,
  );
}
