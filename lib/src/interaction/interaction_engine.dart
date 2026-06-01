import 'dart:ui';

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_pointer.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';
import 'pointer_sample_normalizer.dart';
import 'pointer_session.dart';
import 'pointer_tool_cleanup_coordinator.dart';

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

// The engine deliberately keeps pointer admission state, public tool settings,
// and session value ownership together so later tool behavior cannot split the
// active-session invariant across multiple owners.
// ignore: coupling-between-object-classes, number-of-methods
final class InteractionEngine {
  InteractionEngine({
    required CanvasInteractionMode initialMode,
    required CanvasDrawStyle initialDrawStyle,
    required CanvasPointerPolicy pointerPolicy,
    PointerSampleNormalizer normalizer = const PointerSampleNormalizer(),
    PointerToolCleanupCoordinator cleanupCoordinator =
        const PointerToolCleanupCoordinator(),
  }) : _mode = initialMode,
       _drawStyle = initialDrawStyle,
       _pointerPolicy = pointerPolicy,
       _normalizer = normalizer,
       _cleanupCoordinator = cleanupCoordinator;

  final PointerSampleNormalizer _normalizer;
  final PointerToolCleanupCoordinator _cleanupCoordinator;
  final CanvasInteractionMode _mode;
  final CanvasDrawStyle _drawStyle;
  final CanvasPointerPolicy _pointerPolicy;
  PointerSession? _activeSession;
  int _interactionRevision = 0;
  int _nextSessionId = 1;
  int _nextToken = 1;

  CanvasInteractionMode get mode => _mode;
  CanvasDrawStyle get drawStyle => _drawStyle;
  CanvasPointerPolicy get pointerPolicy => _pointerPolicy;
  int get interactionRevision => _interactionRevision;
  PointerSession? get activeSession => _activeSession;

  PointerCleanupOutcome cleanupPointerTool(PointerCleanupRequest request) {
    return _cleanupCoordinator.cleanup(request);
  }

  InteractionPointerAdmission handlePointerSample(
    CanvasPointerSample sample,
    InteractionPointerContext context,
  ) {
    final normalized = _normalizer.normalizePublicSample(
      sample,
      viewCameraOffset: context.viewCameraOffset,
      controllerEpoch: context.controllerEpoch,
    );

    return switch (sample.phase) {
      CanvasPointerLifecyclePhase.down => _handleDown(normalized, context),
      CanvasPointerLifecyclePhase.move => _handleMove(normalized),
      CanvasPointerLifecyclePhase.up ||
      CanvasPointerLifecyclePhase.cancel => _handleTerminal(normalized),
    };
  }

  InteractionPointerAdmission _handleDown(
    NormalizedPointerSample sample,
    InteractionPointerContext context,
  ) {
    if (_activeSession != null) {
      return InteractionPointerAdmission(
        kind: InteractionPointerAdmissionKind.ignored,
        sample: sample,
      );
    }
    _activeSession = PointerSession(
      kind: switch (_mode) {
        CanvasInteractionMode.move => PointerSessionKind.moveModePointer,
        CanvasInteractionMode.draw => PointerSessionKind.drawModePointer,
      },
      token: PointerSessionToken(_nextToken++),
      controllerEpoch: PointerControllerEpoch(sample.controllerEpoch),
      sessionId: PointerSessionId(_nextSessionId++),
      pointerId: sample.pointerId,
      toolMode: _mode,
      startWorld: sample.worldPosition,
      currentWorld: sample.worldPosition,
      capturedSelectedIds: context.selectedIds,
      capturedMovableIds: context.movableIds,
      previousSelectionIds: context.previousSelectionIds,
      capturedSelectionRevision: context.selectionRevision,
      lastPreview: const CanvasNoPreview(),
    );
    _interactionRevision += 1;

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
    );
  }

  InteractionPointerAdmission _handleMove(NormalizedPointerSample sample) {
    final session = _activeSession;
    if (session == null ||
        session.pointerId != sample.pointerId ||
        session.controllerEpoch.value != sample.controllerEpoch) {
      return InteractionPointerAdmission(
        kind: InteractionPointerAdmissionKind.ignored,
        sample: sample,
      );
    }
    _activeSession = session.updateCurrentWorld(sample.worldPosition);
    _interactionRevision += 1;

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
    );
  }

  InteractionPointerAdmission _handleTerminal(NormalizedPointerSample sample) {
    final session = _activeSession;
    final decision = _normalizer.invalidTerminalCleanupDecision(
      activePointerId: session?.pointerId,
      activeControllerEpoch: session?.controllerEpoch.value,
      terminalPointerId: sample.pointerId,
      terminalControllerEpoch: sample.controllerEpoch,
    );
    if (decision.kind != InvalidTerminalCleanupKind.none) {
      if (decision.shouldCleanupActiveSession) {
        _activeSession = null;
        _interactionRevision += 1;
      }

      return InteractionPointerAdmission(
        kind: decision.shouldCleanupActiveSession
            ? InteractionPointerAdmissionKind.cleanupOnly
            : InteractionPointerAdmissionKind.ignored,
        sample: sample,
        cleanupDecision: decision,
      );
    }
    _activeSession = null;
    _interactionRevision += 1;

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
    );
  }
}
