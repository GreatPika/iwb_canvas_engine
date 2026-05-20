import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_document.dart';
import 'canvas_element.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';
import 'canvas_tools.dart';

/// Public API v1 declaration for [CanvasActionType].
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

/// Public API v1 declaration for [CanvasActionCommitted].
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

/// Public API v1 declaration for [CanvasActionPayload].
sealed class CanvasActionPayload {
  const CanvasActionPayload();
}

/// Public API v1 declaration for [CanvasTransformOperation].
enum CanvasTransformOperation {
  move,
  rotateClockwise,
  rotateCounterClockwise,
  flipVertical,
  flipHorizontal,
}

/// Public API v1 declaration for [CanvasTransformActionPayload].
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

/// Public API v1 declaration for [CanvasSelectionActionPayload].
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

/// Public API v1 declaration for [CanvasDeleteActionPayload].
final class CanvasDeleteActionPayload extends CanvasActionPayload {
  CanvasDeleteActionPayload({
    required Iterable<CanvasElementId> removedElementIds,
  }) : _removedElementIds = List.unmodifiable(removedElementIds);

  final List<CanvasElementId> _removedElementIds;
  List<CanvasElementId> get removedElementIds => _removedElementIds;
}

/// Public API v1 declaration for [CanvasClearActionPayload].
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

/// Public API v1 declaration for [CanvasDrawStrokeActionPayload].
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

/// Public API v1 declaration for [CanvasDrawLineActionPayload].
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

/// Public API v1 declaration for [CanvasEraseActionPayload].
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

/// Public API v1 declaration for [CanvasTextEditActionPayload].
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

/// Public API v1 declaration for [CanvasContextActionTrigger].
enum CanvasContextActionTrigger { doubleTap }

/// Public API v1 declaration for [CanvasContextActionRequested].
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

/// Public API v1 declaration for [CanvasContextActionTarget].
sealed class CanvasContextActionTarget {
  const CanvasContextActionTarget();
}

/// Public API v1 declaration for [CanvasContentElementContextActionTarget].
final class CanvasContentElementContextActionTarget
    extends CanvasContextActionTarget {
  const CanvasContentElementContextActionTarget({
    required this.elementSnapshot,
    required this.boundsWorld,
  });

  final CanvasElement elementSnapshot;
  final Rect boundsWorld;
}

/// Public API v1 declaration for [CanvasEmptyCanvasContextActionTarget].
final class CanvasEmptyCanvasContextActionTarget
    extends CanvasContextActionTarget {
  const CanvasEmptyCanvasContextActionTarget();
}

/// Public API v1 declaration for [CanvasMoveCommitResolver].
typedef CanvasMoveCommitResolver =
    CanvasMoveResolution Function(CanvasMoveCommitRequest request);

/// Public API v1 declaration for [CanvasMoveCommitRequest].
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

@immutable
/// Public API v1 declaration for [CanvasElementRead].
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

  @override
  bool operator ==(Object other) {
    return other is CanvasElementRead &&
        other.id == id &&
        other.kind == kind &&
        other.revision == revision &&
        other.boundsWorld == boundsWorld &&
        other.transform == transform &&
        other.isLocked == isLocked &&
        other.isTransformable == isTransformable;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      kind,
      revision,
      boundsWorld,
      transform,
      isLocked,
      isTransformable,
    );
  }
}

@immutable
/// Public API v1 declaration for [CanvasMoveResolution].
sealed class CanvasMoveResolution {
  const CanvasMoveResolution();
}

@immutable
/// Public API v1 declaration for [CanvasMoveCommit].
final class CanvasMoveCommit extends CanvasMoveResolution {
  const CanvasMoveCommit({required this.delta});
  final Offset delta;

  @override
  bool operator ==(Object other) {
    return other is CanvasMoveCommit && other.delta == delta;
  }

  @override
  int get hashCode => delta.hashCode;
}

@immutable
/// Public API v1 declaration for [CanvasMoveCancel].
final class CanvasMoveCancel extends CanvasMoveResolution {
  const CanvasMoveCancel({this.reason});
  final String? reason;

  @override
  bool operator ==(Object other) {
    return other is CanvasMoveCancel && other.reason == reason;
  }

  @override
  int get hashCode => reason.hashCode;
}
