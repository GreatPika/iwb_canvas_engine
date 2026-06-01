import 'dart:ui';

import '../contracts/public/canvas_ids.dart';
import 'pointer_sample_normalizer.dart';

enum InteractionPointerAdmissionKind { admitted, ignored, cleanupOnly }

final class InteractionPointerAdmission {
  const InteractionPointerAdmission({
    required this.kind,
    required this.sample,
    this.cleanupDecision,
  });

  final InteractionPointerAdmissionKind kind;
  final NormalizedPointerSample sample;
  final InvalidTerminalCleanupDecision? cleanupDecision;
}

final class InteractionPointerContext {
  InteractionPointerContext({
    required this.viewCameraOffset,
    required this.controllerEpoch,
    Iterable<CanvasElementId> selectedIds = const [],
    Iterable<CanvasElementId> movableIds = const [],
    Iterable<CanvasElementId> previousSelectionIds = const [],
    this.selectionRevision = 0,
  }) : selectedIds = List.unmodifiable(selectedIds),
       movableIds = List.unmodifiable(movableIds),
       previousSelectionIds = List.unmodifiable(previousSelectionIds);

  final Offset viewCameraOffset;
  final int controllerEpoch;
  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableIds;
  final List<CanvasElementId> previousSelectionIds;
  final int selectionRevision;
}
