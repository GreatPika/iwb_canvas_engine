import 'dart:ui';

import '../contracts/public/canvas_ids.dart';

abstract interface class InteractionReadPort {
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  );

  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  );

  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request);

  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request);
}

final class SelectedMoveStartReadRequest {
  const SelectedMoveStartReadRequest({required this.worldPosition});

  final Offset worldPosition;
}

final class SelectedMoveStartFacts {
  SelectedMoveStartFacts({
    required Iterable<CanvasElementId> selectedIds,
    required Iterable<CanvasElementId> movableSelectedIds,
    required this.selectionRevision,
    required this.hitSelectedMovable,
  }) : selectedIds = List.unmodifiable(selectedIds),
       movableSelectedIds = List.unmodifiable(movableSelectedIds);

  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableSelectedIds;
  final int selectionRevision;
  final bool hitSelectedMovable;
}

final class SelectedMoveCommitReadRequest {
  SelectedMoveCommitReadRequest({
    required Iterable<CanvasElementId> sessionSelectedIds,
    required Iterable<CanvasElementId> sessionMovableIds,
    required this.selectionRevision,
  }) : sessionSelectedIds = List.unmodifiable(sessionSelectedIds),
       sessionMovableIds = List.unmodifiable(sessionMovableIds);

  final List<CanvasElementId> sessionSelectedIds;
  final List<CanvasElementId> sessionMovableIds;
  final int selectionRevision;
}

final class SelectedMoveCommitFacts {
  SelectedMoveCommitFacts({
    required Iterable<CanvasElementId> movableIds,
    required this.selectionRevision,
    required this.hasDocumentChangesAvailable,
  }) : movableIds = List.unmodifiable(movableIds);

  final List<CanvasElementId> movableIds;
  final int selectionRevision;
  final bool hasDocumentChangesAvailable;
}

final class MarqueeStartReadRequest {
  const MarqueeStartReadRequest();
}

final class MarqueeStartFacts {
  MarqueeStartFacts({
    required Iterable<CanvasElementId> previousSelectedIds,
    required this.selectionRevision,
  }) : previousSelectedIds = List.unmodifiable(previousSelectedIds);

  final List<CanvasElementId> previousSelectedIds;
  final int selectionRevision;
}

final class MarqueeCommitReadRequest {
  const MarqueeCommitReadRequest({required this.rectWorld});

  final Rect rectWorld;
}

final class MarqueeCommitFacts {
  MarqueeCommitFacts({
    required Iterable<CanvasElementId> previousSelectedIds,
    required Iterable<CanvasElementId> nextSelectedIds,
    required this.selectionRevision,
    required this.rectWorld,
  }) : previousSelectedIds = List.unmodifiable(previousSelectedIds),
       nextSelectedIds = List.unmodifiable(nextSelectedIds);

  final List<CanvasElementId> previousSelectedIds;
  final List<CanvasElementId> nextSelectedIds;
  final int selectionRevision;
  final Rect rectWorld;
}
