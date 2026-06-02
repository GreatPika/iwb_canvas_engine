// Keep the engine's adjacent machines visible; wrapper files would hide
// pointer/tool ownership instead of simplifying it.
// ignore_for_file: number-of-imports

import 'dart:ui';

import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_pointer.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';
import 'context_action_router.dart';
import 'draw_stroke_machine.dart';
import 'eraser_machine.dart';
import 'interaction_diagnostics_sink.dart';
import 'interaction_pointer_context.dart';
import 'interaction_read_port.dart';
import 'interaction_request_registry.dart';
import 'line_machine.dart';
import 'move_machine.dart';
import 'pointer_sample_normalizer.dart';
import 'pointer_session.dart';
import 'pointer_tool_cleanup_coordinator.dart';
import 'select_machine.dart';

// Pointer sessions, tool settings, preview cleanup, and revisions stay together
// so the active pointer lifecycle has one auditable owner.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class InteractionEngine {
  InteractionEngine({
    required CanvasInteractionMode initialMode,
    required CanvasDrawStyle initialDrawStyle,
    required CanvasPointerPolicy pointerPolicy,
    PointerSampleNormalizer normalizer = const PointerSampleNormalizer(),
    MoveMachine moveMachine = const MoveMachine(),
    SelectMachine selectMachine = const SelectMachine(),
    DrawStrokeMachine drawStrokeMachine = const DrawStrokeMachine(),
    EraserMachine eraserMachine = const EraserMachine(),
    ContextActionRouter contextActionRouter = const ContextActionRouter(),
    LineMachine lineMachine = const LineMachine(),
    PointerToolCleanupCoordinator cleanupCoordinator =
        const PointerToolCleanupCoordinator(),
    InteractionDiagnosticsSink diagnosticsSink =
        const NoopInteractionDiagnosticsSink(),
  }) : _mode = initialMode,
       _drawStyle = initialDrawStyle,
       _pointerPolicy = pointerPolicy,
       _normalizer = normalizer,
       _moveMachine = moveMachine,
       _selectMachine = selectMachine,
       _drawStrokeMachine = drawStrokeMachine,
       _eraserMachine = eraserMachine,
       _contextActionRouter = contextActionRouter,
       _lineMachine = lineMachine,
       _cleanupCoordinator = cleanupCoordinator,
       _diagnosticsSink = diagnosticsSink;

  final PointerSampleNormalizer _normalizer;
  final MoveMachine _moveMachine;
  final SelectMachine _selectMachine;
  final DrawStrokeMachine _drawStrokeMachine;
  final EraserMachine _eraserMachine;
  final ContextActionRouter _contextActionRouter;
  final LineMachine _lineMachine;
  final PointerToolCleanupCoordinator _cleanupCoordinator;
  final InteractionDiagnosticsSink _diagnosticsSink;
  CanvasInteractionMode _mode;
  CanvasDrawStyle _drawStyle;
  CanvasPointerPolicy _pointerPolicy;
  InteractionReadPort? _readPort;
  PointerSession? _activeSession;
  _PendingLineState? _pendingLine;
  PendingContextTap? _pendingContextTap;
  final InteractionRequestRegistry _requestRegistry =
      InteractionRequestRegistry();
  CanvasPreviewState _preview = const CanvasNoPreview();
  int _interactionRevision = 0;
  int _previewRevision = 0;
  int _nextSessionId = 1;
  int _nextToken = 1;

  // Public state and read-port attachment.
  CanvasInteractionMode get mode => _mode;
  CanvasDrawStyle get drawStyle => _drawStyle;
  CanvasPointerPolicy get pointerPolicy => _pointerPolicy;
  int get interactionRevision => _interactionRevision;
  int get previewRevision => _previewRevision;
  CanvasPreviewState get preview => _preview;
  PointerSession? get activeSession => _activeSession;
  bool get hasPendingLine => _pendingLine != null;
  PendingContextTap? get pendingContextTap => _pendingContextTap;
  CanvasPendingLineStartPreview? get pendingLinePreview =>
      _pendingLine?.preview;
  bool get activeSessionOwnsPendingLine =>
      _activeSession?.kind == PointerSessionKind.drawLineEndpoint;
  InteractionReadPort get readPort {
    final port = _readPort;
    if (port == null) {
      throw StateError('InteractionReadPort has not been attached.');
    }

    return port;
  }

  InteractionRequestGuardFacts? requestFactsFor(
    CanvasInteractionRequestId requestId,
  ) {
    return _requestRegistry.factsFor(requestId);
  }

  TextEditGuardDecision textEditGuardDecision(
    CanvasInteractionRequestId requestId,
  ) {
    final guard = _requestRegistry.liveFactsFor(requestId);
    if (guard == null) {
      return const TextEditGuardDecision.unknownOrRetired();
    }
    final targetElementId = guard.contentElementId;
    if (guard.targetKind != InteractionRequestTargetKind.contentElement ||
        guard.contentElementKind != CanvasElementKind.text ||
        targetElementId == null) {
      _requestRegistry.retire(requestId);

      return const TextEditGuardDecision.rejectedAndRetired();
    }
    final current = readPort.textCommitGuardFacts(
      TextCommitGuardReadRequest(targetElementId: targetElementId),
    );
    if (!_textGuardMatches(guard, current)) {
      _requestRegistry.retire(requestId);

      return const TextEditGuardDecision.rejectedAndRetired();
    }

    return TextEditGuardDecision.accepted(
      targetElementId: targetElementId,
      currentText: current.currentText as String,
    );
  }

  bool retireTextEditRequest(CanvasInteractionRequestId requestId) {
    return _requestRegistry.retire(requestId);
  }

  void attachReadPort(InteractionReadPort readPort) {
    final current = _readPort;
    if (current != null && !identical(current, readPort)) {
      throw StateError('InteractionReadPort has already been attached.');
    }
    _readPort = readPort;
  }

  bool _textGuardMatches(
    InteractionRequestGuardFacts guard,
    TextCommitGuardReadFacts current,
  ) {
    return current.exists &&
        current.targetKind == CanvasElementKind.text &&
        current.controllerEpoch == guard.controllerEpoch &&
        current.generation == guard.generation &&
        current.elementRevision == guard.elementRevision &&
        current.family == guard.family &&
        current.currentText != null;
  }

  // Preview and pending line state.
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

  bool storePendingLineStart({
    required CanvasPendingLineStartPreview preview,
    required int controllerEpoch,
  }) {
    final next = _PendingLineState(
      startWorld: preview.start,
      timestampMs: preview.timestampMs,
      color: preview.color,
      thickness: preview.thickness,
      controllerEpoch: controllerEpoch,
    );
    if (_pendingLinesEqual(_pendingLine, next)) {
      return false;
    }
    _pendingLine = next;

    return replacePreview(next.preview);
  }

  // Cleanup entrypoints.
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

  PointerCleanupOutcome interactiveDisabledCleanup() {
    return _cleanupWithReason(PointerCleanupReason.interactiveDisabled);
  }

  PointerCleanupOutcome finishSelectedMove(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  PointerCleanupOutcome finishMarquee(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  PointerCleanupOutcome finishDrawStroke(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  PointerCleanupOutcome finishLineEndpoint(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  PointerCleanupOutcome finishEraser(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  ContextActionRequestIntent? handleDoubleTap(
    Offset viewPosition,
    InteractionPointerContext context, {
    required int? timestampHintMs,
  }) {
    if (!viewPosition.dx.isFinite || !viewPosition.dy.isFinite) {
      return null;
    }
    if (_pendingContextTap != null) {
      _cleanupPendingContextTapOnly();
    }
    final timestampMs = context.resolveOutputTimestamp(timestampHintMs);
    final worldPosition = viewPosition + context.viewCameraOffset;
    final facts = readPort.directContextTargetFacts(
      ContextTargetReadRequest(worldPosition: worldPosition),
    );

    return _issueContextRequest(
      facts: facts,
      timestampMs: timestampMs,
      viewPosition: viewPosition,
      worldPosition: worldPosition,
    );
  }

  // Tool settings.
  PointerCleanupOutcome setMode(
    CanvasInteractionMode mode, {
    required bool cleanupSelectionMode,
  }) {
    if (_mode == mode) {
      return PointerCleanupOutcome.noChange;
    }
    _mode = mode;
    _interactionRevision += 1;
    if (cleanupSelectionMode ||
        _activeSession != null ||
        _pendingLine != null) {
      return _cleanupWithReason(PointerCleanupReason.modeToolChange);
    }

    return PointerCleanupOutcome.noChange;
  }

  PointerCleanupOutcome setDrawStyle(CanvasDrawStyle style) {
    if (_drawStyle == style) {
      return PointerCleanupOutcome.noChange;
    }
    _drawStyle = style;
    _interactionRevision += 1;

    return _cleanupWithReason(PointerCleanupReason.modeToolChange);
  }

  PointerCleanupOutcome setPointerPolicy(CanvasPointerPolicy policy) {
    if (_pointerPolicy == policy) {
      return PointerCleanupOutcome.noChange;
    }
    _pointerPolicy = policy;
    _interactionRevision += 1;

    return _cleanupWithReason(PointerCleanupReason.modeToolChange);
  }

  // Pointer sample routing.
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
      CanvasPointerLifecyclePhase.up || CanvasPointerLifecyclePhase.cancel =>
        _handleTerminal(normalized, context),
    };
  }

  InteractionPointerAdmission _admitted(NormalizedPointerSample sample) {
    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
    );
  }

  InteractionPointerAdmission _ignored(NormalizedPointerSample sample) {
    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.ignored,
      sample: sample,
      publishRuntimeState: false,
    );
  }

  InteractionPointerAdmission _privateAdmitted(NormalizedPointerSample sample) {
    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      publishRuntimeState: false,
    );
  }

  CanvasSelectedMovePreview _initialSelectedMovePreview(
    NormalizedPointerSample sample,
  ) {
    return CanvasSelectedMovePreview(
      delta: sample.worldPosition - sample.worldPosition,
    );
  }

  bool _replacePreviewAndBumpInteractionRevision(CanvasPreviewState preview) {
    final previewChanged = replacePreview(preview);
    if (previewChanged) {
      _interactionRevision += 1;
    }

    return previewChanged;
  }

  // Pointer down phase.
  InteractionPointerAdmission _handleDown(NormalizedPointerSample sample) {
    if (_activeSession != null) {
      return _ignored(sample);
    }
    final selection = _selectedMoveStartDecision(sample);
    if (selection.admitted) {
      _activeSession = _selectedMoveSession(sample, selection);
      _interactionRevision += 1;

      return _privateAdmitted(sample);
    }
    if (_mode != CanvasInteractionMode.move) {
      return _handleDrawDown(sample);
    }
    final marquee = _selectMachine.start(
      readPort.marqueeStartFacts(const MarqueeStartReadRequest()),
    );
    _activeSession = _marqueeSession(sample, marquee);
    _interactionRevision += 1;

    return _privateAdmitted(sample);
  }

  SelectedMoveStartDecision _selectedMoveStartDecision(
    NormalizedPointerSample sample,
  ) {
    if (_mode != CanvasInteractionMode.move) {
      return const SelectedMoveStartDecision.rejected();
    }

    final facts = readPort.selectedMoveStartFacts(
      SelectedMoveStartReadRequest(worldPosition: sample.worldPosition),
    );
    _recordQueryDiagnostics(facts.query);
    final decision = _moveMachine.start(facts);
    if (!decision.admitted &&
        facts.selectedIds.isNotEmpty &&
        facts.movableSelectedIds.isEmpty) {
      _diagnosticsSink.recordSelectedMoveStartDeniedNotMovable(
        selectedCount: facts.selectedIds.length,
        movableCount: facts.movableSelectedIds.length,
      );
    }

    return decision;
  }

  InteractionPointerAdmission _handleDrawDown(NormalizedPointerSample sample) {
    if (_drawStyle.tool == CanvasDrawTool.eraser) {
      return _handleEraserDown(sample);
    }
    if (_drawStyle.tool == CanvasDrawTool.line) {
      return _handleLineDown(sample);
    }
    final start = _drawStrokeMachine.start(
      tool: _drawStyle.tool,
      startWorld: sample.worldPosition,
      style: _drawStyle,
    );
    final stroke = start.stroke;
    if (!start.admitted || stroke == null) {
      return _ignored(sample);
    }
    _activeSession = _drawStrokeSession(sample, stroke);
    replacePreview(stroke.preview);

    return _admitted(sample);
  }

  InteractionPointerAdmission _handleEraserDown(
    NormalizedPointerSample sample,
  ) {
    final start = _eraserMachine.start(
      tool: _drawStyle.tool,
      startWorld: sample.worldPosition,
      style: _drawStyle,
    );
    final eraser = start.eraser;
    if (!start.admitted || eraser == null) {
      return _ignored(sample);
    }
    final preview = _eraserMachine.initialPreview(
      eraser: eraser,
      facts: readPort.eraserPreviewFacts(
        EraserReadRequest(
          corridorPoints: eraser.points,
          eraserThickness: eraser.thickness,
        ),
      ),
    );
    final nextPreview = preview.preview;
    final nextEraser = preview.eraser;
    if (!preview.changed || nextPreview == null || nextEraser == null) {
      return _ignored(sample);
    }
    _activeSession = _eraserSession(sample, nextEraser, nextPreview);
    replacePreview(nextPreview);

    return _admitted(sample);
  }

  InteractionPointerAdmission _handleLineDown(NormalizedPointerSample sample) {
    final pendingLine = _pendingLine;
    if (pendingLine != null) {
      final start = _lineMachine.startEndpoint(
        pendingLine: pendingLine.capture,
        endWorld: sample.worldPosition,
      );
      _activeSession = _lineEndpointSession(sample, start.line);
      replacePreview(start.line.preview);

      return _admitted(sample);
    }
    final start = _lineMachine.startFirstTap(
      tool: _drawStyle.tool,
      startWorld: sample.worldPosition,
      style: _drawStyle,
    );
    final firstTap = start.firstTap;
    if (!start.admitted || firstTap == null) {
      return _ignored(sample);
    }
    _activeSession = _lineFirstTapSession(sample, firstTap);

    return _admitted(sample);
  }

  // Pointer move phase.
  InteractionPointerAdmission _handleMove(NormalizedPointerSample sample) {
    final session = _activeSession;
    if (session == null ||
        session.pointerId != sample.pointerId ||
        session.controllerEpoch.value != sample.controllerEpoch) {
      return _ignored(sample);
    }
    final updated = session.updateCurrentWorld(sample.worldPosition);
    _activeSession = updated;
    if (_isMoveModeTapCandidate(updated, sample)) {
      return _ignored(sample);
    }
    final previewChanged = _handleSessionMove(updated, sample.worldPosition);
    if (!previewChanged) {
      return _ignored(sample);
    }

    return _admitted(sample);
  }

  bool _handleSessionMove(PointerSession session, Offset currentWorld) {
    return switch (session.kind) {
      PointerSessionKind.moveModePointer => _handleSelectedMovePreview(
        session,
        currentWorld,
      ),
      PointerSessionKind.moveModeMarquee => _handleMarqueePreview(
        session,
        currentWorld,
      ),
      PointerSessionKind.drawModePointer => _handleDrawMove(
        session,
        currentWorld,
      ),
      PointerSessionKind.drawEraserPointer => _handleEraserMove(
        session,
        currentWorld,
      ),
      PointerSessionKind.drawLineFirstTap => false,
      PointerSessionKind.drawLineEndpoint => _handleLineEndpointMove(
        session,
        currentWorld,
      ),
    };
  }

  bool _isMoveModeTapCandidate(
    PointerSession session,
    NormalizedPointerSample sample,
  ) {
    if (!_isContextTapSessionKind(session.kind)) {
      return false;
    }

    return _distanceFromStart(session, sample.worldPosition) <=
        _pointerPolicy.tapSlop;
  }

  bool _handleSelectedMovePreview(PointerSession session, Offset currentWorld) {
    return _replacePreviewAndBumpInteractionRevision(
      _moveMachine
          .preview(session: session, currentWorld: currentWorld)
          .preview,
    );
  }

  bool _handleMarqueePreview(PointerSession session, Offset currentWorld) {
    return _replacePreviewAndBumpInteractionRevision(
      _selectMachine
          .preview(session: session, currentWorld: currentWorld)
          .preview,
    );
  }

  bool _handleDrawMove(PointerSession session, Offset currentWorld) {
    final stroke = session.strokeCapture;
    if (stroke == null) {
      return false;
    }
    final decision = _drawStrokeMachine.preview(
      stroke: stroke,
      currentWorld: currentWorld,
    );
    final updatedStroke = decision.stroke;
    if (!decision.changed || updatedStroke == null) {
      return false;
    }
    _activeSession = session.updateStroke(
      currentWorld: currentWorld,
      stroke: updatedStroke,
    );

    return replacePreview(updatedStroke.preview);
  }

  bool _handleEraserMove(PointerSession session, Offset currentWorld) {
    final eraser = session.eraserCapture;
    if (eraser == null) {
      return false;
    }
    final proposed = eraser.appendPoint(currentWorld);
    if (identical(proposed, eraser)) {
      return false;
    }
    final decision = _eraserMachine.preview(
      eraser: eraser,
      currentWorld: currentWorld,
      facts: readPort.eraserPreviewFacts(
        EraserReadRequest(
          corridorPoints: proposed.points,
          eraserThickness: proposed.thickness,
        ),
      ),
    );
    final updatedEraser = decision.eraser;
    final updatedPreview = decision.preview;
    if (!decision.changed || updatedEraser == null || updatedPreview == null) {
      return false;
    }
    _activeSession = session.updateEraser(
      currentWorld: currentWorld,
      eraser: updatedEraser,
      lastPreview: updatedPreview,
    );

    return replacePreview(updatedPreview);
  }

  bool _handleLineEndpointMove(PointerSession session, Offset currentWorld) {
    final line = session.lineEndpointCapture;
    if (line == null) {
      return false;
    }
    final decision = _lineMachine.preview(line: line, endWorld: currentWorld);
    final updatedLine = decision.line;
    if (!decision.changed || updatedLine == null) {
      return false;
    }
    _activeSession = session.updateLineEndpoint(
      currentWorld: currentWorld,
      line: updatedLine,
    );

    return replacePreview(updatedLine.preview);
  }

  // Pointer terminal phase.
  InteractionPointerAdmission _handleTerminal(
    NormalizedPointerSample sample,
    InteractionPointerContext context,
  ) {
    final session = _activeSession;
    final decision = _terminalCleanupDecision(session, sample);
    if (decision.kind != InvalidTerminalCleanupKind.none) {
      return _handleInvalidTerminal(sample, decision);
    }
    if (sample.phase == CanvasPointerLifecyclePhase.cancel) {
      return _cleanupTerminal(sample, _cancelReasonFor(session));
    }
    if (session != null) {
      return _handleActiveTerminal(sample, session, context);
    }
    return _handleContextTapTerminal(sample, context);
  }

  InteractionPointerAdmission _handleContextTapTerminal(
    NormalizedPointerSample sample,
    InteractionPointerContext context, {
    bool publishRuntimeState = false,
  }) {
    if (sample.phase != CanvasPointerLifecyclePhase.up) {
      return _ignoredWithPublication(sample, publishRuntimeState);
    }
    final pending = _pendingContextTap;
    final facts = _contextTapFacts(sample, pending);
    if (pending == null) {
      return _storePendingContextTap(sample, facts, publishRuntimeState);
    }
    if (!_contextActionRouter.matchesSecondTap((
      pending: pending,
      sample: sample,
      facts: facts,
      doubleTapSlop: _pointerPolicy.doubleTapSlop,
      doubleTapMaxDelayMs: _pointerPolicy.doubleTapMaxDelayMs,
    ))) {
      return _contextTapMismatchAdmission(sample, publishRuntimeState);
    }

    return _contextTapRequestAdmission(
      sample,
      context,
      facts,
      publishRuntimeState,
    );
  }

  InteractionPointerAdmission _ignoredWithPublication(
    NormalizedPointerSample sample,
    bool publishRuntimeState,
  ) {
    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.ignored,
      sample: sample,
      publishRuntimeState: publishRuntimeState,
    );
  }

  ContextTargetReadFacts _contextTapFacts(
    NormalizedPointerSample sample,
    PendingContextTap? pending,
  ) {
    final request = ContextTargetReadRequest(
      worldPosition: sample.worldPosition,
    );
    if (pending == null) {
      return readPort.pendingContextTapFacts(request);
    }

    return readPort.secondContextTapFacts(request);
  }

  InteractionPointerAdmission _storePendingContextTap(
    NormalizedPointerSample sample,
    ContextTargetReadFacts facts,
    bool publishRuntimeState,
  ) {
    _pendingContextTap = _contextActionRouter.pendingTap(
      sample: sample,
      facts: facts,
    );

    return _ignoredWithPublication(sample, publishRuntimeState);
  }

  InteractionPointerAdmission _contextTapMismatchAdmission(
    NormalizedPointerSample sample,
    bool publishRuntimeState,
  ) {
    final outcome = _cleanupWithReason(PointerCleanupReason.contextTap);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.cleanupOnly,
      sample: sample,
      publishRuntimeState: publishRuntimeState || outcome.publicStateNeeded,
    );
  }

  InteractionPointerAdmission _contextTapRequestAdmission(
    NormalizedPointerSample sample,
    InteractionPointerContext context,
    ContextTargetReadFacts facts,
    bool publishRuntimeState,
  ) {
    final outcome = _cleanupWithReason(PointerCleanupReason.contextTap);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      publishRuntimeState: publishRuntimeState || outcome.publicStateNeeded,
      contextRequest: _issueContextRequest(
        facts: facts,
        timestampMs: context.resolveOutputTimestamp(sample.timestampMs),
        viewPosition: sample.viewPosition,
        worldPosition: sample.worldPosition,
      ),
    );
  }

  InteractionPointerAdmission _handleActiveTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
    InteractionPointerContext context,
  ) {
    if (_isContextTapCandidate(session, sample)) {
      final cleanup = _cleanupActiveTapSessionForContextRecognition();

      return _handleContextTapTerminal(
        sample,
        context,
        publishRuntimeState: cleanup.previewChanged,
      );
    }

    return switch (session.kind) {
      PointerSessionKind.moveModePointer => _handleSelectedMoveTerminal(
        sample,
        session,
      ),
      PointerSessionKind.moveModeMarquee => _handleMarqueeTerminal(
        sample,
        session,
      ),
      PointerSessionKind.drawModePointer => _handleDrawTerminal(
        sample,
        session,
      ),
      PointerSessionKind.drawEraserPointer => _handleEraserTerminal(
        sample,
        session,
      ),
      PointerSessionKind.drawLineFirstTap => _handleLineFirstTapTerminal(
        sample,
        session,
        context,
      ),
      PointerSessionKind.drawLineEndpoint => _handleLineEndpointTerminal(
        sample,
        session,
      ),
    };
  }

  bool _isContextTapCandidate(
    PointerSession session,
    NormalizedPointerSample sample,
  ) {
    if (_mode != CanvasInteractionMode.move ||
        sample.phase != CanvasPointerLifecyclePhase.up) {
      return false;
    }
    if (!_isContextTapSessionKind(session.kind)) {
      return false;
    }

    return _isWithinContextTapSlop(session, sample);
  }

  bool _isContextTapSessionKind(PointerSessionKind kind) {
    return switch (kind) {
      PointerSessionKind.moveModePointer ||
      PointerSessionKind.moveModeMarquee => true,
      PointerSessionKind.drawModePointer ||
      PointerSessionKind.drawEraserPointer ||
      PointerSessionKind.drawLineFirstTap ||
      PointerSessionKind.drawLineEndpoint => false,
    };
  }

  bool _isWithinContextTapSlop(
    PointerSession session,
    NormalizedPointerSample sample,
  ) {
    if (_distanceFromStart(session, sample.worldPosition) >
        _pointerPolicy.tapSlop) {
      return false;
    }

    return _distanceFromStart(session, session.currentWorld) <=
        _pointerPolicy.tapSlop;
  }

  double _distanceFromStart(PointerSession session, Offset worldPosition) {
    return (worldPosition - session.startWorld).distance;
  }

  InteractionPointerAdmission _handleDrawTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
  ) {
    final stroke = session.strokeCapture;
    if (stroke == null) {
      return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
    }
    final terminal = _drawStrokeMachine.terminal(
      sessionId: session.sessionId,
      pointerToken: session.token,
      stroke: stroke,
      terminalWorld: sample.worldPosition,
    );

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      strokeCommit: terminal.intent,
    );
  }

  InteractionPointerAdmission _handleEraserTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
  ) {
    final eraser = session.eraserCapture;
    if (eraser == null) {
      return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
    }
    final proposed = eraser.appendPoint(sample.worldPosition);
    final terminal = _eraserMachine.terminal(
      sessionId: session.sessionId,
      pointerToken: session.token,
      eraser: eraser,
      facts: readPort.eraserTerminalFacts(
        EraserReadRequest(
          corridorPoints: proposed.points,
          eraserThickness: proposed.thickness,
        ),
      ),
    );
    final intent = terminal.intent;
    if (intent == null) {
      return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
    }

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      eraserCommit: intent,
    );
  }

  InteractionPointerAdmission _handleLineFirstTapTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
    InteractionPointerContext context,
  ) {
    final firstTap = session.lineFirstTapCapture;
    if (firstTap == null) {
      return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
    }
    final decision = _lineMachine.firstTapTerminal(
      firstTap: firstTap,
      terminalWorld: sample.worldPosition,
      tapSlop: _pointerPolicy.tapSlop,
    );
    final startWorld = decision.startWorld;
    final color = decision.color;
    final thickness = decision.thickness;
    if (!decision.accepted ||
        startWorld == null ||
        color == null ||
        thickness == null) {
      return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
    }
    _activeSession = null;
    storePendingLineStart(
      preview: CanvasPendingLineStartPreview(
        start: startWorld,
        timestampMs: context.resolveOutputTimestamp(sample.timestampMs),
        color: color,
        thickness: thickness,
      ),
      controllerEpoch: sample.controllerEpoch,
    );

    return _admitted(sample);
  }

  InteractionPointerAdmission _handleLineEndpointTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
  ) {
    final line = session.lineEndpointCapture;
    if (line == null) {
      return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
    }
    final terminal = _lineMachine.terminal(
      sessionId: session.sessionId,
      pointerToken: session.token,
      line: line,
      terminalWorld: sample.worldPosition,
    );

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      lineCommit: terminal.intent,
    );
  }

  PointerCleanupReason _cancelReasonFor(PointerSession? session) {
    return switch (session?.kind) {
      PointerSessionKind.moveModeMarquee => PointerCleanupReason.marquee,
      PointerSessionKind.drawModePointer ||
      PointerSessionKind.drawEraserPointer ||
      PointerSessionKind.drawLineFirstTap ||
      PointerSessionKind.drawLineEndpoint => PointerCleanupReason.cancel,
      PointerSessionKind.moveModePointer ||
      null => PointerCleanupReason.selectedMove,
    };
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
    _recordInvalidTerminalCleanup(decision);
    final shouldCleanup =
        decision.shouldCleanupActiveSession ||
        _shouldCleanupLineInvalidTerminal(decision);
    if (shouldCleanup) {
      _recordStaleTerminalRejected(decision);
      _cleanupWithReason(_invalidTerminalCleanupReason(decision));
    }

    return InteractionPointerAdmission(
      kind: shouldCleanup
          ? InteractionPointerAdmissionKind.cleanupOnly
          : InteractionPointerAdmissionKind.ignored,
      sample: sample,
      cleanupDecision: decision,
    );
  }

  bool _shouldCleanupLineInvalidTerminal(
    InvalidTerminalCleanupDecision decision,
  ) {
    if (decision.kind != InvalidTerminalCleanupKind.stalePointer) {
      return false;
    }

    return switch (_activeSession?.kind) {
      PointerSessionKind.drawLineFirstTap ||
      PointerSessionKind.drawLineEndpoint => true,
      PointerSessionKind.moveModePointer ||
      PointerSessionKind.moveModeMarquee ||
      PointerSessionKind.drawModePointer ||
      PointerSessionKind.drawEraserPointer ||
      null => false,
    };
  }

  PointerCleanupReason _invalidTerminalCleanupReason(
    InvalidTerminalCleanupDecision decision,
  ) {
    return switch (decision.kind) {
      InvalidTerminalCleanupKind.noActiveSession =>
        PointerCleanupReason.noOpTerminal,
      InvalidTerminalCleanupKind.stalePointer =>
        PointerCleanupReason.invalidTerminal,
      InvalidTerminalCleanupKind.staleControllerEpoch =>
        PointerCleanupReason.staleTerminal,
      InvalidTerminalCleanupKind.none => PointerCleanupReason.invalidTerminal,
    };
  }

  InteractionPointerAdmission _handleSelectedMoveTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
  ) {
    final selectionCapture = session.selectionCapture;
    final facts = readPort.selectedMoveCommitFacts(
      SelectedMoveCommitReadRequest(
        sessionSelectedIds: selectionCapture.selectedIds,
        sessionMovableIds: selectionCapture.movableIds,
        selectionRevision: selectionCapture.revision,
      ),
    );
    if (facts.skippedSessionIds.isNotEmpty) {
      _diagnosticsSink.recordStaleCandidateRejected(
        reason: 'staleSessionSelection',
        expectedRevision: selectionCapture.revision,
        observedRevision: facts.selectionRevision,
        skippedCandidateCount: facts.skippedSessionIds.length,
      );
    }
    final terminal = _moveMachine.terminal(
      session: session,
      terminalWorld: sample.worldPosition,
      facts: facts,
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

  InteractionPointerAdmission _handleMarqueeTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
  ) {
    final facts = readPort.marqueeCommitFacts(
      MarqueeCommitReadRequest(
        rectWorld: _selectMachine
            .preview(session: session, currentWorld: sample.worldPosition)
            .rectWorld,
      ),
    );
    _recordQueryDiagnostics(facts.query);
    final terminal = _selectMachine.terminal(session: session, facts: facts);
    final intent = terminal.intent;
    if (intent != null) {
      return InteractionPointerAdmission(
        kind: InteractionPointerAdmissionKind.admitted,
        sample: sample,
        marqueeCommit: intent,
      );
    }

    return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
  }

  ContextActionRequestIntent _issueContextRequest({
    required ContextTargetReadFacts facts,
    required int timestampMs,
    required Offset viewPosition,
    required Offset worldPosition,
  }) {
    final guard = _requestRegistry.issueContextRequest(facts);

    return _contextActionRouter.requestIntent((
      requestId: guard.requestId,
      facts: facts,
      timestampMs: timestampMs,
      viewPosition: viewPosition,
      worldPosition: worldPosition,
    ));
  }

  // Session factories.
  PointerSession _marqueeSession(
    NormalizedPointerSample sample,
    MarqueeStartDecision marquee,
  ) {
    return PointerSession.marquee(
      token: PointerSessionToken(_nextToken++),
      controllerEpoch: PointerControllerEpoch(sample.controllerEpoch),
      sessionId: PointerSessionId(_nextSessionId++),
      pointerId: sample.pointerId,
      startWorld: sample.worldPosition,
      currentWorld: sample.worldPosition,
      previousSelectionIds: marquee.previousSelectionIds,
      capturedSelectionRevision: marquee.selectionRevision,
      lastPreview: _selectMachine.initialPreview(sample.worldPosition).preview,
    );
  }

  PointerSession _selectedMoveSession(
    NormalizedPointerSample sample,
    SelectedMoveStartDecision selection,
  ) {
    return PointerSession.selectedMove(
      token: PointerSessionToken(_nextToken++),
      controllerEpoch: PointerControllerEpoch(sample.controllerEpoch),
      sessionId: PointerSessionId(_nextSessionId++),
      pointerId: sample.pointerId,
      startWorld: sample.worldPosition,
      currentWorld: sample.worldPosition,
      capturedSelectedIds: selection.selectedIds,
      capturedMovableIds: selection.movableIds,
      previousSelectionIds: selection.selectedIds,
      capturedSelectionRevision: selection.selectionRevision,
      lastPreview: _initialSelectedMovePreview(sample),
    );
  }

  PointerSession _drawStrokeSession(
    NormalizedPointerSample sample,
    PointerStrokeCapture stroke,
  ) {
    return PointerSession.drawStroke(
      token: PointerSessionToken(_nextToken++),
      controllerEpoch: PointerControllerEpoch(sample.controllerEpoch),
      sessionId: PointerSessionId(_nextSessionId++),
      pointerId: sample.pointerId,
      startWorld: sample.worldPosition,
      currentWorld: sample.worldPosition,
      stroke: stroke,
    );
  }

  PointerSession _eraserSession(
    NormalizedPointerSample sample,
    PointerEraserCapture eraser,
    CanvasPreviewState preview,
  ) {
    return PointerSession.eraser(
      token: PointerSessionToken(_nextToken++),
      controllerEpoch: PointerControllerEpoch(sample.controllerEpoch),
      sessionId: PointerSessionId(_nextSessionId++),
      pointerId: sample.pointerId,
      startWorld: sample.worldPosition,
      currentWorld: sample.worldPosition,
      eraser: eraser,
      lastPreview: preview,
    );
  }

  PointerSession _lineFirstTapSession(
    NormalizedPointerSample sample,
    PointerLineFirstTapCapture firstTap,
  ) {
    return PointerSession.lineFirstTap(
      token: PointerSessionToken(_nextToken++),
      controllerEpoch: PointerControllerEpoch(sample.controllerEpoch),
      sessionId: PointerSessionId(_nextSessionId++),
      pointerId: sample.pointerId,
      startWorld: sample.worldPosition,
      currentWorld: sample.worldPosition,
      firstTap: firstTap,
    );
  }

  PointerSession _lineEndpointSession(
    NormalizedPointerSample sample,
    PointerLineEndpointCapture line,
  ) {
    return PointerSession.lineEndpoint(
      token: PointerSessionToken(_nextToken++),
      controllerEpoch: PointerControllerEpoch(sample.controllerEpoch),
      sessionId: PointerSessionId(_nextSessionId++),
      pointerId: sample.pointerId,
      startWorld: line.startWorld,
      currentWorld: sample.worldPosition,
      line: line,
    );
  }

  // Cleanup internals.
  InteractionPointerAdmission _cleanupTerminal(
    NormalizedPointerSample sample,
    PointerCleanupReason reason,
  ) {
    final outcome = _cleanupWithReason(reason);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.cleanupOnly,
      sample: sample,
      publishRuntimeState: outcome.publicStateNeeded,
    );
  }

  PointerCleanupOutcome _cleanupWithReason(PointerCleanupReason reason) {
    return cleanupPointerTool(
      PointerCleanupRequest(
        reason: reason,
        activePreviewKind: _pointerCleanupPreviewKindFor(_preview.kind),
        hasActiveToken: _activeSession != null,
        hasActiveSession: _activeSession != null,
        ownsPendingLine: activeSessionOwnsPendingLine,
        hasPendingLine: _pendingLine != null,
        hasPendingContextTap: _pendingContextTap != null,
      ),
    );
  }

  PointerCleanupOutcome _cleanupActiveTapSessionForContextRecognition() {
    return cleanupPointerTool(
      PointerCleanupRequest(
        reason: PointerCleanupReason.contextTap,
        activePreviewKind: _pointerCleanupPreviewKindFor(_preview.kind),
        hasActiveToken: _activeSession != null,
        hasActiveSession: _activeSession != null,
        ownsPendingLine: activeSessionOwnsPendingLine,
        hasPendingLine: _pendingLine != null,
        hasPendingContextTap: false,
      ),
    );
  }

  PointerCleanupOutcome _cleanupPendingContextTapOnly() {
    return cleanupPointerTool(
      PointerCleanupRequest(
        reason: PointerCleanupReason.contextTap,
        hasPendingContextTap: _pendingContextTap != null,
      ),
    );
  }

  void _applyCleanupOutcome(PointerCleanupOutcome outcome) {
    if (outcome.previewChanged) {
      clearPreview();
    }
    if (outcome.pendingLineDisposition ==
        PointerPendingLineDisposition.cleared) {
      _pendingLine = null;
    }
    if (outcome.pendingContextTapDisposition ==
        PointerPendingContextTapDisposition.cleared) {
      _pendingContextTap = null;
    }
    if (outcome.sessionDisposition == PointerSessionDisposition.released &&
        _activeSession != null) {
      _activeSession = null;
      _interactionRevision += 1;
    }
  }

  // Diagnostics.
  void _recordQueryDiagnostics(InteractionReadQueryFacts query) {
    switch (query.status) {
      case InteractionReadQueryStatus.notRun:
      case InteractionReadQueryStatus.invalidIndex:
        return;
      case InteractionReadQueryStatus.candidates:
        if (query.skippedCandidateCount > 0) {
          _diagnosticsSink.recordStaleCandidateRejected(
            reason: 'unresolvedCandidate',
            expectedRevision: null,
            observedRevision: null,
            skippedCandidateCount: query.skippedCandidateCount,
          );
        }
      case InteractionReadQueryStatus.staleIndex:
        _diagnosticsSink.recordStaleCandidateRejected(
          reason: 'staleIndex',
          expectedRevision: query.expectedStructuralRevision ?? 0,
          observedRevision: query.observedStructuralRevision ?? 0,
          skippedCandidateCount: 0,
        );
      case InteractionReadQueryStatus.budgetExceeded:
        final reason = _budgetReasonName(query);
        if (query.budgetExceededReason ==
            InteractionReadBudgetExceededReason
                .fallbackCandidateBudgetExceeded) {
          _diagnosticsSink.recordHitTestFallbackObserved(
            reason: reason,
            budget: query.budget,
            observed: query.observed,
          );
        }
        _diagnosticsSink.recordInteractionQueryBudgetExceeded(
          reason: reason,
          budget: query.budget,
          observed: query.observed,
        );
    }
  }

  void _recordInvalidTerminalCleanup(InvalidTerminalCleanupDecision decision) {
    _diagnosticsSink.recordInvalidTerminalCleanup(
      reason: _invalidTerminalReasonName(decision),
    );
  }

  void _recordStaleTerminalRejected(InvalidTerminalCleanupDecision decision) {
    _diagnosticsSink.recordStaleTerminalRejected(
      reason: _invalidTerminalReasonName(decision),
    );
  }
}

String _budgetReasonName(InteractionReadQueryFacts query) {
  return switch (query.budgetExceededReason) {
    InteractionReadBudgetExceededReason.queryTileBudgetExceeded =>
      'queryTileBudgetExceeded',
    InteractionReadBudgetExceededReason.fallbackCandidateBudgetExceeded =>
      'fallbackCandidateBudgetExceeded',
    null => 'unknown',
  };
}

String _invalidTerminalReasonName(InvalidTerminalCleanupDecision decision) {
  return switch (decision.kind) {
    InvalidTerminalCleanupKind.none => 'none',
    InvalidTerminalCleanupKind.noActiveSession => 'noActiveSession',
    InvalidTerminalCleanupKind.stalePointer => 'stalePointer',
    InvalidTerminalCleanupKind.staleControllerEpoch => 'staleControllerEpoch',
  };
}

bool canvasPreviewStatesEqual(
  CanvasPreviewState left,
  CanvasPreviewState right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.kind != right.kind) {
    return false;
  }

  return switch (left) {
    CanvasNoPreview() => _noPreviewsEqual(right),
    CanvasMarqueePreview() => _marqueePreviewsEqual(left, right),
    CanvasSelectedMovePreview() => _selectedMovePreviewsEqual(left, right),
    CanvasPencilStrokePreview() => _pencilStrokesEqual(left, right),
    CanvasMarkerStrokePreview() => _markerStrokesEqual(left, right),
    CanvasPendingLineStartPreview() => _pendingLineStartsEqual(left, right),
    CanvasLinePreview() => _linePreviewsEqual(left, right),
    CanvasEraserPreview() => _eraserPreviewsEqual(left, right),
  };
}

bool _noPreviewsEqual(CanvasPreviewState right) {
  return right is CanvasNoPreview;
}

bool _marqueePreviewsEqual(
  CanvasMarqueePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasMarqueePreview && left.rect == right.rect;
}

bool _selectedMovePreviewsEqual(
  CanvasSelectedMovePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasSelectedMovePreview && left.delta == right.delta;
}

bool _pencilStrokesEqual(
  CanvasPencilStrokePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasPencilStrokePreview && _strokesEqual(left, right);
}

bool _markerStrokesEqual(
  CanvasMarkerStrokePreview left,
  CanvasPreviewState right,
) {
  return right is CanvasMarkerStrokePreview && _strokesEqual(left, right);
}

bool _strokesEqual(CanvasStrokePreview left, CanvasStrokePreview right) {
  return left.color == right.color &&
      left.thickness == right.thickness &&
      left.opacity == right.opacity &&
      _offsetListsEqual(left.points, right.points);
}

bool _pendingLineStartsEqual(
  CanvasPendingLineStartPreview left,
  CanvasPreviewState right,
) {
  if (right is! CanvasPendingLineStartPreview) {
    return false;
  }

  return left.start == right.start &&
      left.timestampMs == right.timestampMs &&
      left.color == right.color &&
      left.thickness == right.thickness;
}

bool _linePreviewsEqual(CanvasLinePreview left, CanvasPreviewState right) {
  if (right is! CanvasLinePreview) {
    return false;
  }

  return left.start == right.start &&
      left.end == right.end &&
      left.color == right.color &&
      left.thickness == right.thickness;
}

bool _eraserPreviewsEqual(CanvasEraserPreview left, CanvasPreviewState right) {
  if (right is! CanvasEraserPreview) {
    return false;
  }

  return left.thickness == right.thickness &&
      _offsetListsEqual(left.corridor, right.corridor);
}

bool _offsetListsEqual(List<Object> left, List<Object> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
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

final class _PendingLineState {
  const _PendingLineState({
    required this.startWorld,
    required this.timestampMs,
    required this.color,
    required this.thickness,
    required this.controllerEpoch,
  });

  final Offset startWorld;
  final int timestampMs;
  final Color color;
  final double thickness;
  final int controllerEpoch;

  CanvasPendingLineStartPreview get preview => CanvasPendingLineStartPreview(
    start: startWorld,
    timestampMs: timestampMs,
    color: color,
    thickness: thickness,
  );

  LinePendingStartCapture get capture => LinePendingStartCapture(
    startWorld: startWorld,
    timestampMs: timestampMs,
    color: color,
    thickness: thickness,
  );
}

bool _pendingLinesEqual(_PendingLineState? left, _PendingLineState right) {
  return left != null &&
      left.startWorld == right.startWorld &&
      left.timestampMs == right.timestampMs &&
      left.color == right.color &&
      left.thickness == right.thickness &&
      left.controllerEpoch == right.controllerEpoch;
}
