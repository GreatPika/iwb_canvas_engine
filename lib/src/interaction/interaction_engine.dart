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
import 'interaction_runtime_intents.dart';
import 'line_machine.dart';
import 'move_machine.dart';
import 'pointer_cleanup_protocol.dart';
import 'pointer_sample_normalizer.dart';
import 'pointer_session.dart';
import 'pointer_session_identity.dart';
import 'pointer_tool_cleanup_coordinator.dart';
import 'select_machine.dart';
import 'text_edit_guard_decision.dart';

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

  void markActiveProvisionalSelectionReplacementApplied({
    required int selectionRevision,
  }) {
    final session = _activeSession;
    if (session == null || session.kind != PointerSessionKind.moveModePointer) {
      return;
    }
    _activeSession = session.markProvisionalSelectionReplacementApplied(
      selectionRevision: selectionRevision,
    );
  }

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
    final guard = _requestRegistry.factsFor(requestId);
    if (guard == null) {
      return const TextEditGuardDecision.unknownOrConsumed();
    }
    final targetElementId = guard.contentElementId;
    if (guard.targetKind != InteractionRequestTargetKind.contentElement ||
        guard.contentElementKind != CanvasElementKind.text ||
        targetElementId == null) {
      _requestRegistry.consume(requestId);

      return const TextEditGuardDecision.rejectedAndConsumed();
    }
    final current = readPort.textCommitGuardFacts(
      TextCommitGuardReadRequest(targetElementId: targetElementId),
    );
    if (!_textGuardMatches(guard, current)) {
      _requestRegistry.consume(requestId);

      return const TextEditGuardDecision.rejectedAndConsumed();
    }

    return TextEditGuardDecision.accepted(
      targetElementId: targetElementId,
      currentText: current.currentText as String,
    );
  }

  bool consumeTextEditRequest(CanvasInteractionRequestId requestId) {
    return _requestRegistry.consume(requestId) != null;
  }

  void clearInteractionRequests() {
    _requestRegistry.clear();
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
        current.targetKind == guard.contentElementKind &&
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
  InteractionCleanupOutcome cleanupPointerTool(PointerCleanupRequest request) {
    final selectionReplacement = _selectionReplacementForCleanup(
      request.reason,
      _activeSession,
    );
    final outcome = _cleanupCoordinator.cleanup(request);
    _applyCleanupOutcome(outcome);

    return _cleanupOutcomeWithSelectionRestore(outcome, selectionReplacement);
  }

  InteractionCleanupOutcome prepareLoadCleanup() {
    final outcome = _cleanupWithReason(
      PointerCleanupReason.preparedLoadSuccess,
    );

    return outcome;
  }

  InteractionCleanupOutcome disposeCleanup() {
    return _cleanupWithReason(PointerCleanupReason.dispose);
  }

  InteractionCleanupOutcome interactiveDisabledCleanup() {
    return _cleanupWithReason(PointerCleanupReason.interactiveDisabled);
  }

  InteractionCleanupOutcome finishSelectedMove(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  InteractionCleanupOutcome finishMarquee(
    PointerCleanupReason reason, {
    bool preservePendingContextTap = false,
  }) {
    return _cleanupWithReason(
      reason,
      preservePendingContextTap: preservePendingContextTap,
    );
  }

  InteractionCleanupOutcome finishDrawStroke(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  InteractionCleanupOutcome finishLineEndpoint(PointerCleanupReason reason) {
    return _cleanupWithReason(reason);
  }

  InteractionCleanupOutcome finishEraser(PointerCleanupReason reason) {
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
    final worldPosition = viewPosition + context.viewCameraOffset;
    final target = readPort.directContextTargetFacts(
      ContextTargetReadRequest(worldPosition: worldPosition),
    );
    final facts = _admittedContextTargetFacts(target);
    if (facts == null) {
      return null;
    }
    return _issueContextRequest(
      facts: facts,
      timestampHintMs: timestampHintMs,
      viewPosition: viewPosition,
      worldPosition: worldPosition,
    );
  }

  // Tool settings.
  InteractionCleanupOutcome setMode(
    CanvasInteractionMode mode, {
    required bool cleanupSelectionMode,
  }) {
    if (_mode == mode) {
      return InteractionCleanupOutcome.noChange;
    }
    _mode = mode;
    _interactionRevision += 1;
    if (cleanupSelectionMode ||
        _activeSession != null ||
        _pendingLine != null) {
      return _cleanupWithReason(PointerCleanupReason.modeToolChange);
    }

    return InteractionCleanupOutcome.noChange;
  }

  InteractionCleanupOutcome setDrawStyle(CanvasDrawStyle style) {
    if (_drawStyle == style) {
      return InteractionCleanupOutcome.noChange;
    }
    _drawStyle = style;
    _interactionRevision += 1;

    return _cleanupWithReason(PointerCleanupReason.modeToolChange);
  }

  InteractionCleanupOutcome setPointerPolicy(CanvasPointerPolicy policy) {
    if (_pointerPolicy == policy) {
      return InteractionCleanupOutcome.noChange;
    }
    _pointerPolicy = policy;
    _interactionRevision += 1;

    return _cleanupWithReason(PointerCleanupReason.modeToolChange);
  }

  // Pointer input routing.
  InteractionPointerAdmission handlePointerInput(
    CanvasPointerInput input,
    InteractionPointerContext context,
  ) {
    return switch (input) {
      CanvasPointerSample() => _handlePointerSample(input, context),
      CanvasPointerTerminalCleanup() => _handleTerminalCleanupInput(
        input,
        context,
      ),
    };
  }

  InteractionPointerAdmission handlePointerSample(
    CanvasPointerSample sample,
    InteractionPointerContext context,
  ) {
    return handlePointerInput(sample, context);
  }

  InteractionPointerAdmission _handlePointerSample(
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
      CanvasPointerLifecyclePhase.move => _handleMove(normalized, context),
      CanvasPointerLifecyclePhase.up || CanvasPointerLifecyclePhase.cancel =>
        _handleTerminal(normalized, context),
    };
  }

  InteractionPointerAdmission _handleTerminalCleanupInput(
    CanvasPointerTerminalCleanup input,
    InteractionPointerContext context,
  ) {
    final decision = _terminalCleanupInputDecision(
      _activeSession,
      input,
      context,
    );

    return _handleInvalidTerminal(null, decision);
  }

  InteractionPointerAdmission _admitted(
    NormalizedPointerSample sample, {
    InteractionSelectionReplacement? selectionReplacement,
    bool markProvisionalSelectionReplacementApplied = false,
  }) {
    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      selectionReplacement: selectionReplacement,
      markProvisionalSelectionReplacementApplied:
          markProvisionalSelectionReplacementApplied,
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

      return _privateAdmitted(sample);
    }
    if (_mode != CanvasInteractionMode.move) {
      return _handleDrawDown(sample);
    }
    final marquee = _selectMachine.start(
      readPort.marqueeStartFacts(const MarqueeStartReadRequest()),
    );
    _activeSession = _marqueeSession(
      sample,
      marquee,
      dragStartSlop: selection.suppressMarqueeDrag ? double.infinity : null,
      suppressCommit: selection.suppressMarqueeDrag,
    );

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
  InteractionPointerAdmission _handleMove(
    NormalizedPointerSample sample,
    InteractionPointerContext context,
  ) {
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
    final blockedReplacement = _blockedProvisionalSelectionReplacement(
      updated,
      context,
    );
    if (blockedReplacement) {
      return _cleanupTerminal(sample, PointerCleanupReason.staleTerminal);
    }
    final move = _handleSessionMove(updated, sample.worldPosition);
    if (!move.previewChanged) {
      return _ignored(sample);
    }

    return _admitted(
      sample,
      selectionReplacement: move.selectionReplacement,
      markProvisionalSelectionReplacementApplied:
          move.markProvisionalSelectionReplacementApplied,
    );
  }

  bool _blockedProvisionalSelectionReplacement(
    PointerSession session,
    InteractionPointerContext context,
  ) {
    final replacement = _provisionalSelectionReplacementFor(session);
    if (replacement == null) {
      return false;
    }

    return !_selectionReplacementExpectedCurrent(context, replacement);
  }

  bool _selectionReplacementExpectedCurrent(
    InteractionPointerContext context,
    InteractionSelectionReplacement replacement,
  ) {
    final expectedIds = replacement.expectedCurrentIds;
    if (expectedIds != null && !_sameIds(context.selectedIds, expectedIds)) {
      return false;
    }
    final expectedRevision = replacement.expectedCurrentRevision;
    if (expectedRevision != null &&
        context.selectionRevision != expectedRevision) {
      return false;
    }

    return true;
  }

  _SessionMoveOutcome _handleSessionMove(
    PointerSession session,
    Offset currentWorld,
  ) {
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
      PointerSessionKind.drawLineFirstTap => _handleLineFirstTapMove(
        session,
        currentWorld,
      ),
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
    if (session.dragPreviewStarted || !_isContextTapSessionKind(session.kind)) {
      return false;
    }

    return _distanceFromStart(session, sample.worldPosition) <=
        session.dragStartSlop;
  }

  _SessionMoveOutcome _handleSelectedMovePreview(
    PointerSession session,
    Offset currentWorld,
  ) {
    final previewChanged = _replacePreviewAndBumpInteractionRevision(
      _moveMachine
          .preview(session: session, currentWorld: currentWorld)
          .preview,
    );
    if (!previewChanged) {
      return const _SessionMoveOutcome.unchanged();
    }
    _activeSession = session.markDragPreviewStarted();
    final selectionReplacement = _provisionalSelectionReplacementFor(session);

    return _SessionMoveOutcome.changed(
      selectionReplacement: selectionReplacement,
      markProvisionalSelectionReplacementApplied: selectionReplacement != null,
    );
  }

  InteractionSelectionReplacement? _provisionalSelectionReplacementFor(
    PointerSession session,
  ) {
    if (session.provisionalSelectionReplacementApplied) {
      return null;
    }
    final selection = session.selectionCapture;
    if (_sameIds(selection.selectedIds, selection.previousIds)) {
      return null;
    }

    return InteractionSelectionReplacement(
      elementIds: selection.selectedIds,
      expectedCurrentIds: selection.previousIds,
      expectedCurrentRevision: selection.revision,
    );
  }

  _SessionMoveOutcome _handleMarqueePreview(
    PointerSession session,
    Offset currentWorld,
  ) {
    final previewChanged = _replacePreviewAndBumpInteractionRevision(
      _selectMachine
          .preview(session: session, currentWorld: currentWorld)
          .preview,
    );
    if (previewChanged) {
      _activeSession = session.markDragPreviewStarted();
    }

    return _SessionMoveOutcome.fromPreviewChanged(
      previewChanged: previewChanged,
    );
  }

  _SessionMoveOutcome _handleDrawMove(
    PointerSession session,
    Offset currentWorld,
  ) {
    final stroke = session.strokeCapture;
    if (stroke == null) {
      return const _SessionMoveOutcome.unchanged();
    }
    final decision = _drawStrokeMachine.preview(
      stroke: stroke,
      currentWorld: currentWorld,
    );
    final updatedStroke = decision.stroke;
    if (!decision.changed || updatedStroke == null) {
      return const _SessionMoveOutcome.unchanged();
    }
    _activeSession = session.updateStroke(
      currentWorld: currentWorld,
      stroke: updatedStroke,
    );

    return _SessionMoveOutcome.fromPreviewChanged(
      previewChanged: replacePreview(updatedStroke.preview),
    );
  }

  _SessionMoveOutcome _handleEraserMove(
    PointerSession session,
    Offset currentWorld,
  ) {
    final eraser = session.eraserCapture;
    if (eraser == null) {
      return const _SessionMoveOutcome.unchanged();
    }
    final proposed = eraser.appendPoint(currentWorld);
    if (identical(proposed, eraser)) {
      return const _SessionMoveOutcome.unchanged();
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
      return const _SessionMoveOutcome.unchanged();
    }
    _activeSession = session.updateEraser(
      currentWorld: currentWorld,
      eraser: updatedEraser,
      lastPreview: updatedPreview,
    );

    return _SessionMoveOutcome.fromPreviewChanged(
      previewChanged: replacePreview(updatedPreview),
    );
  }

  _SessionMoveOutcome _handleLineFirstTapMove(
    PointerSession session,
    Offset currentWorld,
  ) {
    final firstTap = session.lineFirstTapCapture;
    if (firstTap == null ||
        (currentWorld - firstTap.startWorld).distance <=
            session.dragStartSlop) {
      return const _SessionMoveOutcome.unchanged();
    }
    final start = _lineMachine.startDrag(
      firstTap: firstTap,
      endWorld: currentWorld,
    );
    final line = start.line;
    _activeSession = PointerSession.lineEndpoint(
      token: session.token,
      controllerEpoch: session.controllerEpoch,
      sessionId: session.sessionId,
      pointerId: session.pointerId,
      startWorld: line.startWorld,
      currentWorld: currentWorld,
      line: line,
      dragStartSlop: session.dragStartSlop,
    );

    return _SessionMoveOutcome.fromPreviewChanged(
      previewChanged: replacePreview(line.preview),
    );
  }

  _SessionMoveOutcome _handleLineEndpointMove(
    PointerSession session,
    Offset currentWorld,
  ) {
    final line = session.lineEndpointCapture;
    if (line == null) {
      return const _SessionMoveOutcome.unchanged();
    }
    final decision = _lineMachine.preview(line: line, endWorld: currentWorld);
    final updatedLine = decision.line;
    if (!decision.changed || updatedLine == null) {
      return const _SessionMoveOutcome.unchanged();
    }
    _activeSession = session.updateLineEndpoint(
      currentWorld: currentWorld,
      line: updatedLine,
    );

    return _SessionMoveOutcome.fromPreviewChanged(
      previewChanged: replacePreview(updatedLine.preview),
    );
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
    _ContextTapAdmissionCarry carry = const _ContextTapAdmissionCarry(),
  }) {
    if (sample.phase != CanvasPointerLifecyclePhase.up) {
      return _ignoredWithPublication(sample, carry);
    }
    final pending = _pendingContextTap;
    final target = _contextTapFacts(sample, pending);
    final facts = _admittedContextTargetFacts(target);
    if (facts == null) {
      return _contextTapRejectedAdmission(sample, pending, carry);
    }
    if (pending == null) {
      return _storePendingContextTap(sample, facts, carry);
    }
    if (!_contextActionRouter.matchesSecondTap((
      pending: pending,
      sample: sample,
      facts: facts,
      doubleTapSlop: _pointerPolicy.doubleTapSlop,
      doubleTapMaxDelayMs: _pointerPolicy.doubleTapMaxDelayMs,
    ))) {
      return _contextTapMismatchAdmission(sample, carry);
    }

    return _contextTapRequestAdmission(sample, context, facts, carry);
  }

  InteractionPointerAdmission _ignoredWithPublication(
    NormalizedPointerSample sample,
    _ContextTapAdmissionCarry carry,
  ) {
    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.ignored,
      sample: sample,
      publishRuntimeState: carry.publicStateNeeded,
      selectionReplacement: carry.selectionReplacement,
    );
  }

  ContextTargetReadOutcome _contextTapFacts(
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

  ContextTargetReadFacts? _admittedContextTargetFacts(
    ContextTargetReadOutcome outcome,
  ) {
    switch (outcome) {
      case AdmittedContextTargetRead(:final facts):
        return facts;
      case RejectedContextTargetRead(:final query):
        _recordQueryDiagnostics(query);

        return null;
    }
  }

  InteractionPointerAdmission _storePendingContextTap(
    NormalizedPointerSample sample,
    ContextTargetReadFacts facts,
    _ContextTapAdmissionCarry carry,
  ) {
    _pendingContextTap = _contextActionRouter.pendingTap(
      sample: sample,
      facts: facts,
    );

    return _ignoredWithPublication(sample, carry);
  }

  InteractionPointerAdmission _contextTapRejectedAdmission(
    NormalizedPointerSample sample,
    PendingContextTap? pending,
    _ContextTapAdmissionCarry carry,
  ) {
    if (pending == null) {
      return _ignoredWithPublication(sample, carry);
    }

    return _contextTapMismatchAdmission(sample, carry);
  }

  InteractionPointerAdmission _contextTapMismatchAdmission(
    NormalizedPointerSample sample,
    _ContextTapAdmissionCarry carry,
  ) {
    final outcome = _cleanupWithReason(PointerCleanupReason.contextTap);
    final updatedCarry = carry.withCleanup(outcome);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.cleanupOnly,
      sample: sample,
      publishRuntimeState: updatedCarry.publicStateNeeded,
      selectionReplacement: updatedCarry.selectionReplacement,
      cleanupOutcome: outcome,
    );
  }

  InteractionPointerAdmission _contextTapRequestAdmission(
    NormalizedPointerSample sample,
    InteractionPointerContext _,
    ContextTargetReadFacts facts,
    _ContextTapAdmissionCarry carry,
  ) {
    final outcome = _cleanupWithReason(PointerCleanupReason.contextTap);
    final updatedCarry = carry.withCleanup(outcome);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      publishRuntimeState: updatedCarry.publicStateNeeded,
      selectionReplacement: updatedCarry.selectionReplacement,
      cleanupOutcome: outcome,
      contextRequest: _issueContextRequest(
        facts: facts,
        timestampHintMs: sample.timestampMs,
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
    final selectedMoveSelectionTap = _trySelectedMoveSelectionTapTerminal(
      sample,
      session,
      context,
    );
    if (selectedMoveSelectionTap != null) {
      return selectedMoveSelectionTap;
    }
    if (_isMarqueeSelectionTapCandidate(session, sample)) {
      final selectionTap = _tryMarqueeSelectionTapTerminal(sample, session);
      if (selectionTap != null) {
        return selectionTap;
      }
    }
    if (_isContextTapCandidate(session, sample)) {
      final cleanup = _cleanupActiveTapSessionForContextRecognition();

      return _handleContextTapTerminal(
        sample,
        context,
        carry: _ContextTapAdmissionCarry.fromCleanup(cleanup),
      );
    }

    return _handleNonTapActiveTerminal(sample, session, context);
  }

  InteractionPointerAdmission? _trySelectedMoveSelectionTapTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
    InteractionPointerContext context,
  ) {
    final selection = session.selectionCapture;
    if (session.kind != PointerSessionKind.moveModePointer ||
        _sameIds(selection.selectedIds, selection.previousIds) ||
        !_selectedMoveTapSelectionIsCurrent(session, context) ||
        !_isWithinContextTapSlop(session, sample)) {
      return null;
    }
    final intent = _terminalPointSelectionIntentFor(
      sample: sample,
      session: session,
      previousSelectionIds: selection.previousIds,
    );
    if (intent == null) {
      return null;
    }
    final preservePendingContextTap = _tryStorePendingContextTap(sample);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      selectionReplacement: _provisionalTapTerminalSelectionReplacement(
        session,
      ),
      marqueeCommit: _marqueeIntentWithContextTapDisposition(
        intent,
        preservePendingContextTap: preservePendingContextTap,
      ),
    );
  }

  InteractionSelectionReplacement? _provisionalTapTerminalSelectionReplacement(
    PointerSession session,
  ) {
    if (!session.provisionalSelectionReplacementApplied) {
      return null;
    }
    final selection = session.selectionCapture;

    return InteractionSelectionReplacement(
      elementIds: selection.previousIds,
      expectedCurrentIds: selection.selectedIds,
      expectedCurrentRevision: session.provisionalSelectionReplacementRevision,
    );
  }

  MarqueeCommitIntent? _terminalPointSelectionIntentFor({
    required NormalizedPointerSample sample,
    required PointerSession session,
    required List<CanvasElementId> previousSelectionIds,
  }) {
    final facts = readPort.marqueeCommitFacts(
      MarqueeCommitReadRequest(
        rectWorld: Rect.fromPoints(sample.worldPosition, sample.worldPosition),
      ),
    );
    _recordQueryDiagnostics(facts.query);

    return _selectMachine
        .terminal(
          session: session.asSelectionTerminalSession(
            previousSelectionIds: previousSelectionIds,
            selectionRevision: facts.selectionRevision,
            terminalWorld: sample.worldPosition,
          ),
          facts: facts,
        )
        .intent;
  }

  bool _selectedMoveTapSelectionIsCurrent(
    PointerSession session,
    InteractionPointerContext context,
  ) {
    final selection = session.selectionCapture;
    if (!session.provisionalSelectionReplacementApplied) {
      return context.selectionRevision == selection.revision &&
          _sameIds(context.selectedIds, selection.previousIds);
    }

    return context.selectionRevision ==
            session.provisionalSelectionReplacementRevision &&
        _sameIds(context.selectedIds, selection.selectedIds);
  }

  InteractionPointerAdmission _handleNonTapActiveTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
    InteractionPointerContext context,
  ) {
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

  InteractionPointerAdmission? _tryMarqueeSelectionTapTerminal(
    NormalizedPointerSample sample,
    PointerSession session,
  ) {
    final facts = readPort.marqueeCommitFacts(
      MarqueeCommitReadRequest(
        rectWorld: Rect.fromPoints(sample.worldPosition, sample.worldPosition),
      ),
    );
    _recordQueryDiagnostics(facts.query);
    final terminal = _selectMachine.terminal(session: session, facts: facts);
    final intent = terminal.intent;
    if (intent == null) {
      return null;
    }
    final preservePendingContextTap = _tryStorePendingContextTap(sample);

    return InteractionPointerAdmission(
      kind: InteractionPointerAdmissionKind.admitted,
      sample: sample,
      marqueeCommit: _marqueeIntentWithContextTapDisposition(
        intent,
        preservePendingContextTap: preservePendingContextTap,
      ),
    );
  }

  bool _tryStorePendingContextTap(NormalizedPointerSample sample) {
    final facts = _admittedContextTargetFacts(
      readPort.pendingContextTapFacts(
        ContextTargetReadRequest(worldPosition: sample.worldPosition),
      ),
    );
    if (facts == null) {
      return false;
    }
    _pendingContextTap = _contextActionRouter.pendingTap(
      sample: sample,
      facts: facts,
    );

    return true;
  }

  MarqueeCommitIntent _marqueeIntentWithContextTapDisposition(
    MarqueeCommitIntent intent, {
    required bool preservePendingContextTap,
  }) {
    if (!preservePendingContextTap) {
      return intent;
    }

    return MarqueeCommitIntent(
      sessionId: intent.sessionId,
      pointerToken: intent.pointerToken,
      previousSelectionIds: intent.previousSelectionIds,
      nextSelectionIds: intent.nextSelectionIds,
      rectWorld: intent.rectWorld,
      preservePendingContextTap: true,
    );
  }

  bool _isMarqueeSelectionTapCandidate(
    PointerSession session,
    NormalizedPointerSample sample,
  ) {
    return _mode == CanvasInteractionMode.move &&
        sample.phase == CanvasPointerLifecyclePhase.up &&
        session.kind == PointerSessionKind.moveModeMarquee &&
        _isWithinContextTapSlop(session, sample);
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

  InvalidTerminalCleanupDecision _terminalCleanupInputDecision(
    PointerSession? session,
    CanvasPointerTerminalCleanup input,
    InteractionPointerContext context,
  ) {
    return _normalizer.terminalCleanupInputDecision(
      activePointerId: session?.pointerId,
      activeControllerEpoch: session?.controllerEpoch.value,
      terminalPointerId: input.pointerId,
      terminalControllerEpoch: context.controllerEpoch,
    );
  }

  InteractionPointerAdmission _handleInvalidTerminal(
    NormalizedPointerSample? sample,
    InvalidTerminalCleanupDecision decision,
  ) {
    _recordInvalidTerminalCleanup(decision);
    if (_isStaleTerminalDecision(decision)) {
      _recordStaleTerminalRejected(decision);
    }
    final shouldCleanup =
        decision.shouldCleanupActiveSession ||
        _shouldCleanupLineInvalidTerminal(decision);
    InteractionCleanupOutcome? outcome;
    if (shouldCleanup) {
      outcome = _cleanupWithReason(_invalidTerminalCleanupReason(decision));
    }

    return InteractionPointerAdmission(
      kind: shouldCleanup
          ? InteractionPointerAdmissionKind.cleanupOnly
          : InteractionPointerAdmissionKind.ignored,
      sample: sample,
      publishRuntimeState: outcome?.publicStateNeeded ?? false,
      selectionReplacement: outcome?.selectionReplacement,
      cleanupDecision: decision,
      cleanupOutcome: outcome,
    );
  }

  bool _isStaleTerminalDecision(InvalidTerminalCleanupDecision decision) {
    return switch (decision.kind) {
      InvalidTerminalCleanupKind.stalePointer ||
      InvalidTerminalCleanupKind.staleControllerEpoch => true,
      InvalidTerminalCleanupKind.none ||
      InvalidTerminalCleanupKind.invalidTerminalPosition ||
      InvalidTerminalCleanupKind.noActiveSession => false,
    };
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
      InvalidTerminalCleanupKind.invalidTerminalPosition =>
        PointerCleanupReason.invalidTerminal,
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
        provisionalSelectionReplacementApplied:
            session.provisionalSelectionReplacementApplied,
        provisionalSelectionReplacementRevision:
            session.provisionalSelectionReplacementRevision,
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
    if (session.marqueeCommitSuppressed) {
      return _cleanupTerminal(sample, PointerCleanupReason.noOpTerminal);
    }

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
    required int? timestampHintMs,
    required Offset viewPosition,
    required Offset worldPosition,
  }) {
    final guard = _requestRegistry.issueContextRequest(facts);

    return _contextActionRouter.requestIntent((
      requestId: guard.requestId,
      facts: facts,
      timestampHintMs: timestampHintMs,
      viewPosition: viewPosition,
      worldPosition: worldPosition,
    ));
  }

  // Session factories.
  PointerSession _marqueeSession(
    NormalizedPointerSample sample,
    MarqueeStartDecision marquee, {
    double? dragStartSlop,
    bool suppressCommit = false,
  }) {
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
      dragStartSlop: dragStartSlop ?? _effectiveDragStartSlop,
      suppressCommit: suppressCommit,
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
      previousSelectionIds: selection.previousSelectionIds,
      capturedSelectionRevision: selection.selectionRevision,
      lastPreview: _initialSelectedMovePreview(sample),
      dragStartSlop: _effectiveDragStartSlop,
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
      dragStartSlop: _effectiveDragStartSlop,
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
      dragStartSlop: _effectiveDragStartSlop,
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
      dragStartSlop: _effectiveDragStartSlop,
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
      dragStartSlop: _effectiveDragStartSlop,
    );
  }

  double get _effectiveDragStartSlop {
    return _pointerPolicy.dragStartSlop ?? _pointerPolicy.tapSlop;
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
      selectionReplacement: outcome.selectionReplacement,
      cleanupOutcome: outcome,
    );
  }

  InteractionCleanupOutcome _cleanupWithReason(
    PointerCleanupReason reason, {
    bool preservePendingContextTap = false,
  }) {
    return cleanupPointerTool(
      PointerCleanupRequest(
        reason: reason,
        activePreviewKind: _pointerCleanupPreviewKindFor(_preview.kind),
        hasActiveToken: _activeSession != null,
        hasActiveSession: _activeSession != null,
        ownsPendingLine: activeSessionOwnsPendingLine,
        hasPendingLine: _pendingLine != null,
        hasPendingContextTap: _pendingContextTap != null,
        preservePendingContextTap: preservePendingContextTap,
      ),
    );
  }

  InteractionSelectionReplacement? _selectionReplacementForCleanup(
    PointerCleanupReason reason,
    PointerSession? session,
  ) {
    if (reason == PointerCleanupReason.postSuccessCommit ||
        session == null ||
        !session.provisionalSelectionReplacementApplied) {
      return null;
    }

    final selection = session.selectionCapture;

    return InteractionSelectionReplacement(
      elementIds: selection.previousIds,
      expectedCurrentIds: selection.selectedIds,
      expectedCurrentRevision: session.provisionalSelectionReplacementRevision,
    );
  }

  InteractionCleanupOutcome _cleanupOutcomeWithSelectionRestore(
    PointerCleanupOutcome outcome,
    InteractionSelectionReplacement? selectionReplacement,
  ) {
    return InteractionCleanupOutcome(
      pointer: outcome,
      selectionReplacement: selectionReplacement,
    );
  }

  InteractionCleanupOutcome _cleanupActiveTapSessionForContextRecognition() {
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

  InteractionCleanupOutcome _cleanupPendingContextTapOnly() {
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
    InvalidTerminalCleanupKind.invalidTerminalPosition =>
      'invalidTerminalPosition',
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

bool _sameIds(List<CanvasElementId> left, List<CanvasElementId> right) {
  if (left.length != right.length) {
    return false;
  }
  final rightSet = right.toSet();

  return left.every(rightSet.contains);
}

final class _SessionMoveOutcome {
  const _SessionMoveOutcome.changed({
    this.selectionReplacement,
    this.markProvisionalSelectionReplacementApplied = false,
  }) : previewChanged = true;

  const _SessionMoveOutcome.unchanged()
    : previewChanged = false,
      selectionReplacement = null,
      markProvisionalSelectionReplacementApplied = false;

  factory _SessionMoveOutcome.fromPreviewChanged({
    required bool previewChanged,
  }) {
    return previewChanged
        ? const _SessionMoveOutcome.changed()
        : const _SessionMoveOutcome.unchanged();
  }

  final bool previewChanged;
  final InteractionSelectionReplacement? selectionReplacement;
  final bool markProvisionalSelectionReplacementApplied;
}

final class _ContextTapAdmissionCarry {
  const _ContextTapAdmissionCarry({
    this.publishRuntimeState = false,
    this.selectionReplacement,
  });

  factory _ContextTapAdmissionCarry.fromCleanup(
    InteractionCleanupOutcome cleanup,
  ) {
    return _ContextTapAdmissionCarry(
      publishRuntimeState: cleanup.publicStateNeeded,
      selectionReplacement: cleanup.selectionReplacement,
    );
  }

  final bool publishRuntimeState;
  final InteractionSelectionReplacement? selectionReplacement;

  bool get publicStateNeeded =>
      publishRuntimeState || selectionReplacement != null;

  _ContextTapAdmissionCarry withCleanup(InteractionCleanupOutcome cleanup) {
    return _ContextTapAdmissionCarry(
      publishRuntimeState: publishRuntimeState || cleanup.publicStateNeeded,
      selectionReplacement:
          selectionReplacement ?? cleanup.selectionReplacement,
    );
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
