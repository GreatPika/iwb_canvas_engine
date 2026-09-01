import 'dart:async';
import 'dart:ui';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/internal/deletion_entry_projection_port.dart';
import '../contracts/public/canvas_tools.dart';
import 'pointer_cleanup_protocol.dart';
import 'pointer_session_identity.dart';

final class ContextActionRequestIntent {
  const ContextActionRequestIntent({required this.pendingRequest});

  final PendingContextActionRequest pendingRequest;
}

final class PendingContextActionRequest {
  const PendingContextActionRequest({
    required this.requestId,
    required this.trigger,
    required this.target,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.timestampHintMs,
    required this.viewPosition,
    required this.worldPosition,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasContextActionTrigger trigger;
  final CanvasContextActionTarget target;
  final int controllerEpoch;
  final int documentRevision;
  final int? timestampHintMs;
  final Offset viewPosition;
  final Offset worldPosition;

  CanvasContextActionRequested toRequest({required int timestampMs}) {
    return CanvasContextActionRequested(
      requestId: requestId,
      trigger: trigger,
      target: target,
      controllerEpoch: controllerEpoch,
      documentRevision: documentRevision,
      timestampMs: timestampMs,
      viewPosition: viewPosition,
      worldPosition: worldPosition,
    );
  }
}

final class SelectedMoveCommitIntent {
  SelectedMoveCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required this.proposedDelta,
    required Iterable<CanvasElementId> selectedElementIdsBefore,
    required Iterable<CanvasElementId> movableIds,
    required Iterable<CanvasElementRead> movedElements,
    required this.documentSummary,
    required this.selectionBoundsWorld,
  }) : selectedElementIdsBefore = List.unmodifiable(selectedElementIdsBefore),
       movableIds = List.unmodifiable(movableIds),
       movedElements = List.unmodifiable(movedElements);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final Offset proposedDelta;
  final List<CanvasElementId> selectedElementIdsBefore;
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
    this.preservePendingContextTap = false,
  }) : previousSelectionIds = List.unmodifiable(previousSelectionIds),
       nextSelectionIds = List.unmodifiable(nextSelectionIds);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final List<CanvasElementId> previousSelectionIds;
  final List<CanvasElementId> nextSelectionIds;
  final Rect rectWorld;
  final bool preservePendingContextTap;
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

/// Per-entry work while materializing eraser deletion IDs from Store facts.
@visibleForTesting
enum EraserDeletionIdMaterializationWorkEvent { entryVisited }

final class EraserCommitIntent {
  EraserCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required this.eraserThickness,
    required Iterable<Offset> corridorWorld,
    required this.erasedEntries,
  }) : _corridorWorld = List.unmodifiable(corridorWorld);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final double eraserThickness;
  final List<Offset> _corridorWorld;
  List<Offset> get corridorWorld => _corridorWorld;
  int get corridorPointCount => _corridorWorld.length;
  // This is the same immutable Store projection accepted by the terminal
  // decision. IDs remain a compatibility view, never an independent payload.
  final List<DeletionEntryFacts> erasedEntries;

  static final Object _erasedElementIdMaterializationWorkZoneKey = Object();

  /// Observes assertion-gated entry visits while materializing eraser IDs.
  @visibleForTesting
  static T observeErasedElementIdMaterializationWork<T>(
    void Function(EraserDeletionIdMaterializationWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(
    operation,
    zoneValues: {_erasedElementIdMaterializationWorkZoneKey: sink},
  );

  List<CanvasElementId> get erasedElementIds => List.unmodifiable(
    erasedEntries.map((entry) {
      assert(
        _recordErasedElementIdMaterializationWork(),
        'eraser deletion ID materialization observation failed',
      );
      return entry.id;
    }),
  );

  static bool _recordErasedElementIdMaterializationWork() {
    final sink = Zone.current[_erasedElementIdMaterializationWorkZoneKey];
    if (sink is void Function(EraserDeletionIdMaterializationWorkEvent)) {
      sink(EraserDeletionIdMaterializationWorkEvent.entryVisited);
    }
    return true;
  }
}

final class InteractionSelectionReplacement {
  InteractionSelectionReplacement({
    required Iterable<CanvasElementId> elementIds,
    Iterable<CanvasElementId>? expectedCurrentIds,
    this.expectedCurrentRevision,
  }) : elementIds = List.unmodifiable(elementIds),
       expectedCurrentIds = expectedCurrentIds == null
           ? null
           : List.unmodifiable(expectedCurrentIds);

  final List<CanvasElementId> elementIds;
  final List<CanvasElementId>? expectedCurrentIds;
  final int? expectedCurrentRevision;
}

final class InteractionCleanupOutcome {
  const InteractionCleanupOutcome({
    required this.pointer,
    this.selectionReplacement,
  });

  static const InteractionCleanupOutcome noChange = InteractionCleanupOutcome(
    pointer: PointerCleanupOutcome.noChange,
  );

  final PointerCleanupOutcome pointer;
  final InteractionSelectionReplacement? selectionReplacement;

  bool get previewChanged => pointer.previewChanged;
  bool get publicStateNeeded =>
      pointer.publicStateNeeded || selectionReplacement != null;
  PointerCleanupRepaintTarget get repaintTarget => pointer.repaintTarget;
  PointerPendingLineDisposition get pendingLineDisposition =>
      pointer.pendingLineDisposition;
  bool get disposeBeforeStreamClose => pointer.disposeBeforeStreamClose;
}
