import 'dart:ui';

import 'canvas_document.dart';
import 'canvas_element.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';
import 'canvas_tools.dart';

enum CanvasActionType {
  moveSelection,
  selectMarquee,
  transformSelection,
  deleteElements,
  clearContent,
  drawPencil,
  drawMarker,
  drawLine,
  erase,
  editText,
}

final class CanvasActionCommitted {
  CanvasActionCommitted({
    required this.actionId,
    required this.type,
    required Iterable<CanvasElementId> elementIds,
    required this.timestampMs,
    required this.payload,
  }) : _elementIds = List.unmodifiable(elementIds);

  final CanvasActionId actionId;
  final CanvasActionType type;
  final List<CanvasElementId> _elementIds;
  final int timestampMs;
  final CanvasActionPayload payload;
  List<CanvasElementId> get elementIds => _elementIds;
}

sealed class CanvasActionPayload {
  const CanvasActionPayload();
}

enum CanvasTransformOperation {
  move,
  rotateClockwise,
  rotateCounterClockwise,
  flipVertical,
  flipHorizontal,
}

final class CanvasTransformActionPayload extends CanvasActionPayload {
  const CanvasTransformActionPayload({
    required this.delta,
    required this.operation,
    this.pivotWorld,
  });

  final CanvasTransform delta;
  final CanvasTransformOperation operation;
  final Offset? pivotWorld;
}

final class CanvasSelectionActionPayload extends CanvasActionPayload {
  CanvasSelectionActionPayload({
    required Iterable<CanvasElementId> previousSelection,
    required Iterable<CanvasElementId> nextSelection,
    this.marqueeRectWorld,
  }) : _previousSelection = List.unmodifiable(previousSelection),
       _nextSelection = List.unmodifiable(nextSelection);

  final List<CanvasElementId> _previousSelection;
  final List<CanvasElementId> _nextSelection;
  final Rect? marqueeRectWorld;
  List<CanvasElementId> get previousSelection => _previousSelection;
  List<CanvasElementId> get nextSelection => _nextSelection;
}

final class CanvasDeleteActionPayload extends CanvasActionPayload {
  CanvasDeleteActionPayload({
    required Iterable<CanvasElementId> removedElementIds,
  }) : _removedElementIds = List.unmodifiable(removedElementIds);

  final List<CanvasElementId> _removedElementIds;
  List<CanvasElementId> get removedElementIds => _removedElementIds;
}

final class CanvasClearActionPayload extends CanvasActionPayload {
  CanvasClearActionPayload({
    required Iterable<CanvasElementId> removedElementIds,
    required Iterable<CanvasResourceId> removedResourceIds,
  }) : _removedElementIds = List.unmodifiable(removedElementIds),
       _removedResourceIds = List.unmodifiable(removedResourceIds);

  final List<CanvasElementId> _removedElementIds;
  final List<CanvasResourceId> _removedResourceIds;
  List<CanvasElementId> get removedElementIds => _removedElementIds;
  List<CanvasResourceId> get removedResourceIds => _removedResourceIds;
}

final class CanvasDrawStrokeActionPayload extends CanvasActionPayload {
  const CanvasDrawStrokeActionPayload({
    required this.tool,
    required this.color,
    required this.thickness,
    required this.opacity,
    required this.pointCount,
  });

  final CanvasDrawTool tool;
  final Color color;
  final double thickness;
  final double opacity;
  final int pointCount;
}

final class CanvasDrawLineActionPayload extends CanvasActionPayload {
  const CanvasDrawLineActionPayload({
    required this.color,
    required this.thickness,
    required this.opacity,
    required this.startWorld,
    required this.endWorld,
  });

  final Color color;
  final double thickness;
  final double opacity;
  final Offset startWorld;
  final Offset endWorld;
}

final class CanvasEraseActionPayload extends CanvasActionPayload {
  CanvasEraseActionPayload({
    required this.eraserThickness,
    required Iterable<CanvasElementId> erasedElementIds,
    required this.corridorPointCount,
  }) : _erasedElementIds = List.unmodifiable(erasedElementIds);

  final double eraserThickness;
  final List<CanvasElementId> _erasedElementIds;
  final int corridorPointCount;
  List<CanvasElementId> get erasedElementIds => _erasedElementIds;
}

final class CanvasTextEditActionPayload extends CanvasActionPayload {
  const CanvasTextEditActionPayload({
    required this.requestId,
    required this.previousTextLength,
    required this.nextTextLength,
  });

  final CanvasInteractionRequestId requestId;
  final int previousTextLength;
  final int nextTextLength;
}

enum CanvasContextActionTrigger { doubleTap }

final class CanvasContextActionRequested {
  const CanvasContextActionRequested({
    required this.requestId,
    required this.trigger,
    required this.target,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.timestampMs,
    required this.viewPosition,
    required this.worldPosition,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasContextActionTrigger trigger;
  final CanvasContextActionTarget target;
  final int controllerEpoch;
  final int documentRevision;
  final int timestampMs;
  final Offset viewPosition;
  final Offset worldPosition;
}

sealed class CanvasContextActionTarget {
  const CanvasContextActionTarget();
}

final class CanvasContentElementContextActionTarget
    extends CanvasContextActionTarget {
  const CanvasContentElementContextActionTarget({
    required this.elementSnapshot,
    required this.boundsWorld,
  });

  final CanvasElement elementSnapshot;
  final Rect boundsWorld;
}

final class CanvasEmptyCanvasContextActionTarget
    extends CanvasContextActionTarget {
  const CanvasEmptyCanvasContextActionTarget();
}

typedef CanvasMoveCommitResolver =
    CanvasMoveResolution Function(CanvasMoveCommitRequest request);

final class CanvasMoveCommitRequest {
  CanvasMoveCommitRequest({
    required this.documentSummary,
    required Iterable<CanvasElementRead> movedElements,
    required this.proposedDelta,
    required this.selectionBoundsWorld,
    required this.timestampMs,
  }) : _movedElements = List.unmodifiable(movedElements);

  final CanvasDocumentSummary documentSummary;
  final List<CanvasElementRead> _movedElements;
  final Offset proposedDelta;
  final Rect selectionBoundsWorld;
  final int timestampMs;
  List<CanvasElementRead> get movedElements => _movedElements;
}

final class CanvasElementRead {
  const CanvasElementRead({
    required this.id,
    required this.kind,
    required this.revision,
    required this.boundsWorld,
    required this.transform,
    required this.isLocked,
    required this.isTransformable,
  });

  final CanvasElementId id;
  final CanvasElementKind kind;
  final int revision;
  final Rect boundsWorld;
  final CanvasTransform transform;
  final bool isLocked;
  final bool isTransformable;
}

sealed class CanvasMoveResolution {
  const CanvasMoveResolution();
}

final class CanvasMoveCommit extends CanvasMoveResolution {
  const CanvasMoveCommit({required this.delta});
  final Offset delta;
}

final class CanvasMoveCancel extends CanvasMoveResolution {
  const CanvasMoveCancel({this.reason});
  final String? reason;
}
