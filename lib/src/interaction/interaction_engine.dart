import '../contracts/public/canvas_pointer.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';
import 'interaction_pointer_context.dart';
import 'interaction_read_port.dart';
import 'move_machine.dart';
import 'pointer_sample_normalizer.dart';
import 'pointer_session.dart';
import 'pointer_tool_cleanup_coordinator.dart';
import 'preview_state_equivalence.dart';

// The engine deliberately keeps pointer admission state, public tool settings,
// and session value ownership together so later tool behavior cannot split the
// active-session invariant across multiple owners.
// Keeping preview cleanup with session cleanup avoids a second mutable owner for
// the public interaction revision and active pointer lifecycle.
// ignore: coupling-between-object-classes, number-of-methods, weighted-methods-per-class
final class InteractionEngine {
  InteractionEngine({
    required CanvasInteractionMode initialMode,
    required CanvasDrawStyle initialDrawStyle,
    required CanvasPointerPolicy pointerPolicy,
    PointerSampleNormalizer normalizer = const PointerSampleNormalizer(),
    MoveMachine moveMachine = const MoveMachine(),
    PointerToolCleanupCoordinator cleanupCoordinator =
        const PointerToolCleanupCoordinator(),
  }) : _mode = initialMode,
       _drawStyle = initialDrawStyle,
       _pointerPolicy = pointerPolicy,
       _normalizer = normalizer,
       _moveMachine = moveMachine,
       _cleanupCoordinator = cleanupCoordinator;

  final PointerSampleNormalizer _normalizer;
  final MoveMachine _moveMachine;
  final PointerToolCleanupCoordinator _cleanupCoordinator;
  final CanvasInteractionMode _mode;
  final CanvasDrawStyle _drawStyle;
  final CanvasPointerPolicy _pointerPolicy;
  InteractionReadPort? _readPort;
  PointerSession? _activeSession;
  CanvasPreviewState _preview = const CanvasNoPreview();
  int _interactionRevision = 0;
  int _previewRevision = 0;
  int _nextSessionId = 1;
  int _nextToken = 1;

  CanvasInteractionMode get mode => _mode;
  CanvasDrawStyle get drawStyle => _drawStyle;
  CanvasPointerPolicy get pointerPolicy => _pointerPolicy;
  int get interactionRevision => _interactionRevision;
  int get previewRevision => _previewRevision;
  CanvasPreviewState get preview => _preview;
  PointerSession? get activeSession => _activeSession;
  InteractionReadPort get readPort {
    final port = _readPort;
    if (port == null) {
      throw StateError('InteractionReadPort has not been attached.');
    }

    return port;
  }

  void attachReadPort(InteractionReadPort readPort) {
    final current = _readPort;
    if (current != null && !identical(current, readPort)) {
      throw StateError('InteractionReadPort has already been attached.');
    }
    _readPort = readPort;
  }

  bool replacePreview(CanvasPreviewState preview) {
    if (canvasPreviewStatesEqual(_preview, preview)) {
      return false;
    }
    _preview = preview;
    _previewRevision += 1;

    return true;
  }

  bool clearPreview() {
    return replacePreview(const CanvasNoPreview());
  }

  PointerCleanupOutcome cleanupPointerTool(PointerCleanupRequest request) {
    final outcome = _cleanupCoordinator.cleanup(request);
    _applyCleanupOutcome(outcome);

    return outcome;
  }

  PointerCleanupOutcome prepareLoadCleanup() {
    final outcome = _cleanupWithReason(
      PointerCleanupReason.preparedLoadSuccess,
    );

    return outcome;
  }

  PointerCleanupOutcome disposeCleanup() {
    return _cleanupWithReason(PointerCleanupReason.dispose);
  }

  PointerCleanupOutcome finishSelectedMove(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
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
      CanvasPointerLifecyclePhase.down => _handleDown(normalized),
      CanvasPointerLifecyclePhase.move => _handleMove(normalized),
      CanvasPointerLifecyclePhase.up ||
      CanvasPointerLifecyclePhase.cancel => _handleTerminal(normalized),
    };
  }

  InteractionPointerAdmission _handleDown(NormalizedPointerSample sample) {
    if (_activeSession != null) {
      return InteractionPointerAdmission(
        kind: InteractionPointerAdmissionKind.ignored,
        sample: sample,
      );
    }
    final selection = _selectedMoveStartDecision(sample);
    if (!selection.admitted) {
      return InteractionPointerAdmission(
        kind: InteractionPointerAdmissionKind.ignored,
        sample: sample,
      );
    }
    _activeSession = _selectedMoveSession(sample, selection);
    replacePreview(
      CanvasSelectedMovePreview(
        delta: sample.worldPosition - sample.worldPosition,
      ),
    );
    _interactionRevision += 1;

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
    );
  }

  PointerSession _selectedMoveSession(
    NormalizedPointerSample sample,
    SelectedMoveStartDecision selection,
  ) {
    return PointerSession(
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
      capturedSelectedIds: selection.selectedIds,
      capturedMovableIds: selection.movableIds,
      previousSelectionIds: selection.selectedIds,
      capturedSelectionRevision: selection.selectionRevision,
      lastPreview: CanvasSelectedMovePreview(
        delta: sample.worldPosition - sample.worldPosition,
      ),
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
    final updated = session.updateCurrentWorld(sample.worldPosition);
    _activeSession = updated;
    if (updated.kind == PointerSessionKind.moveModePointer) {
      replacePreview(
        _moveMachine
            .preview(session: updated, currentWorld: sample.worldPosition)
            .preview,
      );
    }
    _interactionRevision += 1;

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
    );
  }

  InteractionPointerAdmission _handleTerminal(NormalizedPointerSample sample) {
    final session = _activeSession;
    final decision = _terminalCleanupDecision(session, sample);
    if (decision.kind != InvalidTerminalCleanupKind.none) {
      return _handleInvalidTerminal(sample, decision);
    }
    if (sample.phase == CanvasPointerLifecyclePhase.cancel) {
      return _cleanupTerminal(sample, PointerCleanupReason.selectedMove);
    }
    if (session?.kind == PointerSessionKind.moveModePointer) {
      return _handleSelectedMoveTerminal(sample, session as PointerSession);
    }
    _activeSession = null;
    _interactionRevision += 1;

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
    );
  }

  InvalidTerminalCleanupDecision _terminalCleanupDecision(
    PointerSession? session,
    NormalizedPointerSample sample,
  ) {
    return _normalizer.invalidTerminalCleanupDecision(
      activePointerId: session?.pointerId,
      activeControllerEpoch: session?.controllerEpoch.value,
      terminalPointerId: sample.pointerId,
      terminalControllerEpoch: sample.controllerEpoch,
    );
  }

  InteractionPointerAdmission _handleInvalidTerminal(
    NormalizedPointerSample sample,
    InvalidTerminalCleanupDecision decision,
  ) {
    if (decision.shouldCleanupActiveSession) {
      _cleanupWithReason(PointerCleanupReason.staleTerminal);
    }

    return InteractionPointerAdmission(
      kind: decision.shouldCleanupActiveSession
          ? InteractionPointerAdmissionKind.cleanupOnly
          : InteractionPointerAdmissionKind.ignored,
      sample: sample,
      cleanupDecision: decision,
    );
  }

  InteractionPointerAdmission _handleSelectedMoveTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
  ) {
    final terminal = _moveMachine.terminal(
      session: session,
      terminalWorld: sample.worldPosition,
      facts: readPort.selectedMoveCommitFacts(
        SelectedMoveCommitReadRequest(
          sessionSelectedIds: session.capturedSelectedIds,
          sessionMovableIds: session.capturedMovableIds,
          selectionRevision: session.capturedSelectionRevision,
        ),
      ),
    );
    final intent = terminal.intent;
    if (intent != null) {
      return InteractionPointerAdmission(
        kind: InteractionPointerAdmissionKind.admitted,
        sample: sample,
        selectedMoveCommit: intent,
      );
    }

    return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
  }

  InteractionPointerAdmission _cleanupTerminal(
    NormalizedPointerSample sample,
    PointerCleanupReason reason,
  ) {
    _cleanupWithReason(reason);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.cleanupOnly,
      sample: sample,
    );
  }

  SelectedMoveStartDecision _selectedMoveStartDecision(
    NormalizedPointerSample sample,
  ) {
    if (_mode != CanvasInteractionMode.move) {
      return const SelectedMoveStartDecision.rejected();
    }

    return _moveMachine.start(
      readPort.selectedMoveStartFacts(
        SelectedMoveStartReadRequest(worldPosition: sample.worldPosition),
      ),
    );
  }

  PointerCleanupOutcome _cleanupWithReason(PointerCleanupReason reason) {
    return cleanupPointerTool(
      PointerCleanupRequest(
        reason: reason,
        activePreviewKind: _pointerCleanupPreviewKindFor(_preview.kind),
        hasActiveToken: _activeSession != null,
        hasActiveSession: _activeSession != null,
      ),
    );
  }

  void _applyCleanupOutcome(PointerCleanupOutcome outcome) {
    if (outcome.previewChanged) {
      clearPreview();
    }
    if (outcome.sessionDisposition == PointerSessionDisposition.released &&
        _activeSession != null) {
      _activeSession = null;
      _interactionRevision += 1;
    }
  }
}

PointerCleanupPreviewKind _pointerCleanupPreviewKindFor(
  CanvasPreviewKind kind,
) {
  return switch (kind) {
    CanvasPreviewKind.none => PointerCleanupPreviewKind.none,
    CanvasPreviewKind.marquee => PointerCleanupPreviewKind.marquee,
    CanvasPreviewKind.selectedMove => PointerCleanupPreviewKind.selectedMove,
    CanvasPreviewKind.pencilStroke => PointerCleanupPreviewKind.pencilStroke,
    CanvasPreviewKind.markerStroke => PointerCleanupPreviewKind.markerStroke,
    CanvasPreviewKind.pendingLineStart =>
      PointerCleanupPreviewKind.pendingLineStart,
    CanvasPreviewKind.linePreview => PointerCleanupPreviewKind.linePreview,
    CanvasPreviewKind.eraser => PointerCleanupPreviewKind.eraser,
  };
}
