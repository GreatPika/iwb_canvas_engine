// This fixture exercises the full diagnostics route across public runtime,
// interaction, codec, and internal diagnostic records, so the boundary imports
// stay together instead of being split into metric-shaped fixtures.
// ignore_for_file: number-of-imports

import 'dart:ui';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_diagnostics.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_diagnostics_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _testRecordsEveryInteractionDiagnosticCode();
  _testInteractionGuardPathsRouteDiagnostics();
  _testResolverReentrantMutationDiagnostic();
  _testCodecDiagnosticsRemainDataCodes();
  _testDiagnosticCodesStayInternal();
}

void _testRecordsEveryInteractionDiagnosticCode() {
  test('records every P10 interaction diagnostic code internally', () {
    final hub = DiagnosticsHub(
      policy: CanvasDiagnosticPolicy.verbose(
        maxPreviewLength: 4,
        maxListEntries: 3,
      ),
    );

    for (final code in InteractionDiagnosticCode.values) {
      recordInteractionReliabilityDiagnostic(
        hub,
        code: code,
        details: () => {
          'text': 'abcdef',
          'items': [1, 2, 3, 4],
          'payload': _SensitivePayload(),
        },
      );
    }

    expect(
      hub.records.map((record) => record.code),
      InteractionDiagnosticCode.values.map(DiagnosticCode.interaction),
    );
    expect(hub.records, everyElement(_isSanitizedInteractionRecord));
  });
}

// The route proof reads as one scenario: start denial, stale candidate, stale
// terminal cleanup, and bounded diagnostics must be checked against one hub.
// ignore: halstead-volume, source-lines-of-code
void _testInteractionGuardPathsRouteDiagnostics() {
  test('interaction guard paths route bounded diagnostics without actions', () {
    final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());
    final diagnostics = RuntimeInteractionDiagnosticsAdapter(hub);

    _rejectSelectedMoveWithFallbackBudget(diagnostics);
    _rejectSelectedMoveWithStaleCandidate(diagnostics);
    _rejectStaleTerminal(diagnostics);

    expect(
      hub.records.map((record) => record.code).toSet(),
      containsAll({
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.hitTestFallbackObserved,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.interactionQueryBudgetExceeded,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.staleCandidateRejected,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.staleTerminalRejected,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.invalidTerminalCleanup,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.selectedMoveStartDeniedNotMovable,
        ),
      }),
    );
    expect(
      hub.records,
      everyElement(
        isA<DiagnosticRecord>()
            .having(
              (record) => record.source,
              'source',
              DiagnosticSource.interaction,
            )
            .having(
              (record) => record.severity,
              'severity',
              DiagnosticSeverity.warning,
            ),
      ),
    );
  });
}

// The reentrancy proof keeps resolver mutation, rollback, action silence, and
// diagnostic emission in one scenario so no assertion can drift from the cause.
// ignore: halstead-volume
void _testResolverReentrantMutationDiagnostic() {
  test('resolver reentrant mutation rejection records no public action', () {
    late RuntimeRoot root;
    final actions = <CanvasActionCommitted>[];
    root = RuntimeRoot(
      initialDocument: _document(),
      config: CanvasRuntimeConfig(
        diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
        moveCommitResolver: (_) {
          root.selection.clearSelection();

          return const CanvasMoveCommit(delta: Offset(1, 1));
        },
      ),
    );
    addTearDown(root.dispose);
    root.actions.listen(actions.add);
    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(2, 0)),
    );

    expect(
      () => root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, const Offset(2, 0)),
      ),
      throwsStateError,
    );

    expect(actions, isEmpty);
    expect(_rect(root, 'a').transform, CanvasTransform.identity);
    expect(
      root.diagnosticRecords.map((record) => record.code),
      contains(
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.resolverReentrantMutationRejected,
        ),
      ),
    );
  });
}

void _testCodecDiagnosticsRemainDataCodes() {
  test('codec diagnostics remain wrapped as data codes', () {
    final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());
    final exception = CanvasDataException(
      code: CanvasDataErrorCode.invalidJson,
      message: 'Invalid JSON.',
      path: r'$.document',
    );

    recordSchemaV1FailureDiagnostic(hub, exception);

    expect(
      hub.records.single.code,
      const DiagnosticCode.data(CanvasDataErrorCode.invalidJson),
    );
    expect(hub.records.single.source, DiagnosticSource.codec);
  });
}

void _testDiagnosticCodesStayInternal() {
  test('diagnostic code types are not exported from the public barrel', () {
    final diagnosticCode = File(
      'lib/src/diagnostics/diagnostic_code.dart',
    ).readAsStringSync();
    final publicBarrel = _publicBarrelSource();

    expect(diagnosticCode, contains('sealed class DiagnosticCode'));
    expect(diagnosticCode, contains('final class DiagnosticDataCode'));
    expect(diagnosticCode, contains('final class DiagnosticInteractionCode'));
    expect(diagnosticCode, contains('enum InteractionDiagnosticCode'));
    expect(publicBarrel, isNot(contains('diagnostic_code.dart')));
    expect(publicBarrel, isNot(contains('DiagnosticCode')));
    expect(publicBarrel, isNot(contains('InteractionDiagnosticCode')));
  });
}

void _rejectSelectedMoveWithFallbackBudget(
  RuntimeInteractionDiagnosticsAdapter diagnostics,
) {
  final engine = _engine(
    diagnostics,
    selectedMoveStartFacts: SelectedMoveStartFacts(
      selectedIds: [CanvasElementId('a')],
      movableSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
      hitSelectedMovable: false,
      query: const InteractionReadQueryFacts.budgetExceeded(
        budgetExceededReason:
            InteractionReadBudgetExceededReason.fallbackCandidateBudgetExceeded,
        budget: 1,
        observed: 2,
      ),
    ),
  );

  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
}

void _rejectSelectedMoveWithStaleCandidate(
  RuntimeInteractionDiagnosticsAdapter diagnostics,
) {
  final engine = _engine(
    diagnostics,
    selectedMoveStartFacts: SelectedMoveStartFacts(
      selectedIds: [CanvasElementId('a')],
      movableSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
      hitSelectedMovable: false,
      query: const InteractionReadQueryFacts.candidates(
        candidateCount: 1,
        skippedCandidateCount: 1,
      ),
    ),
  );

  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
}

void _rejectStaleTerminal(RuntimeInteractionDiagnosticsAdapter diagnostics) {
  final engine = _engine(
    diagnostics,
    selectedMoveStartFacts: SelectedMoveStartFacts(
      selectedIds: [CanvasElementId('a')],
      movableSelectedIds: [CanvasElementId('a')],
      controllerEpoch: 0,
      selectionRevision: 0,
      hitSelectedMovable: true,
    ),
  );

  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.up, Offset.zero),
    _context(controllerEpoch: 1),
  );
}

InteractionEngine _engine(
  RuntimeInteractionDiagnosticsAdapter diagnostics, {
  required SelectedMoveStartFacts selectedMoveStartFacts,
}) {
  final engine = InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle(),
    pointerPolicy: CanvasPointerPolicy(),
    diagnosticsSink: diagnostics,
  );
  engine.attachReadPort(
    _FakeInteractionReadPort(startFacts: selectedMoveStartFacts),
  );

  return engine;
}

InteractionPointerContext _context({int controllerEpoch = 0}) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: controllerEpoch,
  );
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position,
) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(10, 10)),
        ],
      ),
    ],
  );
}

CanvasRectElement _rect(RuntimeRoot root, String id) {
  return root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasRectElement>()
      .firstWhere((element) => element.id == CanvasElementId(id));
}

String _publicBarrelSource() {
  return File('lib/iwb_canvas_engine.dart').readAsStringSync();
}

final Matcher _isSanitizedInteractionRecord = isA<DiagnosticRecord>()
    .having((record) => record.source, 'source', DiagnosticSource.interaction)
    .having((record) => record.severity, 'severity', DiagnosticSeverity.warning)
    .having((record) => record.details['text'], 'text', 'abcd<truncated>')
    .having((record) => record.details['item<truncated>'], 'items', [1, 2, 3])
    .having((record) => record.details['payl<truncated>'], 'payload', {
      'unsupportedType': '_Sen<truncated>',
    });

final class _FakeInteractionReadPort implements InteractionReadPort {
  const _FakeInteractionReadPort({required this.startFacts});

  final SelectedMoveStartFacts startFacts;

  @override
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  ) {
    return startFacts;
  }

  @override
  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  ) {
    throw UnimplementedError('selected move commit is outside this fixture.');
  }

  @override
  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request) {
    return MarqueeStartFacts(
      previousSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
    );
  }

  @override
  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request) {
    return MarqueeCommitFacts(
      previousSelectedIds: const [],
      nextSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
      rectWorld: request.rectWorld,
    );
  }

  @override
  EraserReadFacts eraserPreviewFacts(EraserReadRequest request) {
    return EraserReadFacts(
      corridorPoints: request.corridorPoints,
      erasedElementIds: const [],
      eraserThickness: request.eraserThickness,
      controllerEpoch: 0,
      documentRevision: 0,
      exactCheckCount: 0,
      exactBudgetExceeded: false,
    );
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    return eraserPreviewFacts(request);
  }

  @override
  ContextTargetReadFacts directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    return const ContextTargetReadFacts.emptyCanvas(
      controllerEpoch: 0,
      documentRevision: 0,
    );
  }

  @override
  ContextTargetReadFacts pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    return directContextTargetFacts(request);
  }

  @override
  ContextTargetReadFacts secondContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    return directContextTargetFacts(request);
  }

  @override
  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  ) {
    return TextCommitGuardReadFacts.missing(
      targetElementId: request.targetElementId,
      controllerEpoch: 0,
      documentRevision: 0,
    );
  }
}

final class _SensitivePayload {}
