import 'dart:ui';

import '../contracts/public/canvas_ids.dart';
import 'draw_stroke_machine.dart';
import 'line_machine.dart';
import 'move_machine.dart';
import 'pointer_sample_normalizer.dart';
import 'select_machine.dart';

enum InteractionPointerAdmissionKind { admitted, ignored, cleanupOnly }

typedef InteractionOutputTimestampResolver = int Function(int? timestampHintMs);

final class InteractionPointerAdmission {
  const InteractionPointerAdmission({
    required this.kind,
    required this.sample,
    this.cleanupDecision,
    this.selectedMoveCommit,
    this.marqueeCommit,
    this.strokeCommit,
    this.lineCommit,
  });

  final InteractionPointerAdmissionKind kind;
  final NormalizedPointerSample sample;
  final InvalidTerminalCleanupDecision? cleanupDecision;
  final SelectedMoveCommitIntent? selectedMoveCommit;
  final MarqueeCommitIntent? marqueeCommit;
  final DrawStrokeCommitIntent? strokeCommit;
  final DrawLineCommitIntent? lineCommit;
}

final class InteractionPointerContext {
  InteractionPointerContext({
    required this.viewCameraOffset,
    required this.controllerEpoch,
    Iterable<CanvasElementId> selectedIds = const [],
    Iterable<CanvasElementId> movableIds = const [],
    Iterable<CanvasElementId> previousSelectionIds = const [],
    this.selectionRevision = 0,
    InteractionOutputTimestampResolver? resolveOutputTimestamp,
  }) : selectedIds = List.unmodifiable(selectedIds),
       movableIds = List.unmodifiable(movableIds),
       previousSelectionIds = List.unmodifiable(previousSelectionIds),
       _resolveOutputTimestamp = resolveOutputTimestamp;

  final Offset viewCameraOffset;
  final int controllerEpoch;
  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableIds;
  final List<CanvasElementId> previousSelectionIds;
  final int selectionRevision;
  final InteractionOutputTimestampResolver? _resolveOutputTimestamp;

  int resolveOutputTimestamp(int? timestampHintMs) {
    final resolver = _resolveOutputTimestamp;
    if (resolver == null) {
      throw StateError(
        'Interaction output timestamp resolver is not attached.',
      );
    }

    return resolver(timestampHintMs);
  }
}
