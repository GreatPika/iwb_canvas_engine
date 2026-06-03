import 'dart:ui';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_tools.dart';
import 'pointer_session_identity.dart';

final class ContextActionRequestIntent {
  const ContextActionRequestIntent({required this.request});

  final CanvasContextActionRequested request;
}

final class SelectedMoveCommitIntent {
  SelectedMoveCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required this.proposedDelta,
    required Iterable<CanvasElementId> movableIds,
    required Iterable<CanvasElementRead> movedElements,
    required this.documentSummary,
    required this.selectionBoundsWorld,
  }) : movableIds = List.unmodifiable(movableIds),
       movedElements = List.unmodifiable(movedElements);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final Offset proposedDelta;
  final List<CanvasElementId> movableIds;
  final List<CanvasElementRead> movedElements;
  final CanvasDocumentSummary documentSummary;
  final Rect selectionBoundsWorld;
}

final class MarqueeCommitIntent {
  MarqueeCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required Iterable<CanvasElementId> previousSelectionIds,
    required Iterable<CanvasElementId> nextSelectionIds,
    required this.rectWorld,
  }) : previousSelectionIds = List.unmodifiable(previousSelectionIds),
       nextSelectionIds = List.unmodifiable(nextSelectionIds);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final List<CanvasElementId> previousSelectionIds;
  final List<CanvasElementId> nextSelectionIds;
  final Rect rectWorld;
}

final class DrawStrokeCommitIntent {
  DrawStrokeCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required this.tool,
    required Iterable<Offset> points,
    required this.color,
    required this.thickness,
    required this.opacity,
  }) : points = List.unmodifiable(points);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final CanvasDrawTool tool;
  final List<Offset> points;
  final Color color;
  final double thickness;
  final double opacity;
}

final class DrawLineCommitIntent {
  const DrawLineCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required this.startWorld,
    required this.endWorld,
    required this.color,
    required this.thickness,
    required this.opacity,
  });

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final Offset startWorld;
  final Offset endWorld;
  final Color color;
  final double thickness;
  final double opacity;
}

final class EraserCommitIntent {
  EraserCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required this.eraserThickness,
    required this.corridorPointCount,
    required Iterable<CanvasElementId> erasedElementIds,
  }) : erasedElementIds = List.unmodifiable(erasedElementIds);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final double eraserThickness;
  final int corridorPointCount;
  final List<CanvasElementId> erasedElementIds;
}
