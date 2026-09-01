// This integrated runtime fixture names every cross-owner dependency needed to
// falsify delivery work; a helper split would duplicate its public setup.
// ignore_for_file: number-of-imports

import 'dart:ui';
import '../../support/id_admission_work_recorder.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/id_admission.dart'
    show IdAdmissionWorkKind, IdAdmissionWorkPhase;
import 'package:iwb_canvas_engine/src/store/layer_table.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test('pencil marker and line commits add elements and emit draw actions', () {
    return expectLater(_verifyDrawCommitDelivery(), completes);
  });

  test('draw delivery failure cleans interaction and emits no action', () {
    return expectLater(_verifyDrawDeliveryFailureRollback(), completes);
  });

  test(
    'line delivery failure cleans pending interaction and preserves its id',
    () {
      return expectLater(_verifyLineDeliveryFailureRollback(), completes);
    },
  );

  test(
    'runtime draw and line routes observe one unreserved candidate each',
    () {
      return expectLater(_verifyRuntimeRouteIdAdmissionWork(), completes);
    },
  );

  test('programmatic addElement remains action silent', () {
    return expectLater(_verifyProgrammaticAddElementActionSilence(), completes);
  });

  test('draw routes clean previews before every delivery callback', () {
    return expectLater(_verifyDrawRouteDeliveryCleanup(), completes);
  });

  test('draw resolver receives exact entries and settles accepted leases', () {
    return expectLater(_verifyUnifiedDrawCommitRequests(), completes);
  });

  test(
    'lease callbacks retain resolver exclusions during terminal delivery',
    () {
      return expectLater(_verifyLeaseCallbackGuardPrecedence(), completes);
    },
  );

  test('cancelled draw discards its candidate and remains action silent', () {
    return expectLater(_verifyCancelledDrawCommit(), completes);
  });
}

Future<void> _verifyLeaseCallbackGuardPrecedence() async {
  final scenario = _caughtLeaseScenario();
  final root = scenario.root;
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });
  _drawPencil(root);
  _drawMarker(root);
  await Future<void>.delayed(Duration.zero);

  _expectCaughtLeaseCallbackOutcome(
    root: root,
    actions: actions,
    committedLease: scenario.committedLease,
    abortedLease: scenario.abortedLease,
  );
  _expectUnhandledLeaseCallbackRejections();
  await _expectThrowingLeaseCallbacksAreContained();
}

_CaughtLeaseScenario _caughtLeaseScenario() {
  late RuntimeRoot root;
  final committedLease = _DrawLease();
  final abortedLease = _DrawLease();
  var resolverCalls = 0;
  root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    config: CanvasRuntimeConfig(
      diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
      commitResolver: (_) {
        resolverCalls += 1;
        return resolverCalls == 1
            ? CanvasCommitAccept(lease: committedLease)
            : CanvasMoveCommitAccept(
                delta: const Offset(1, 0),
                lease: abortedLease,
              );
      },
    ),
  );
  committedLease.onCommitted = () => _catchLeaseReentrantOperations(root);
  abortedLease.onAborted = () => _catchLeaseReentrantOperations(root);

  return (
    root: root,
    committedLease: committedLease,
    abortedLease: abortedLease,
  );
}

void _expectCaughtLeaseCallbackOutcome({
  required RuntimeRoot root,
  required List<CanvasActionCommitted> actions,
  required _DrawLease committedLease,
  required _DrawLease abortedLease,
}) {
  expect(actions, hasLength(1));
  expect(committedLease.committedCalls, 1);
  expect(committedLease.abortedCalls, 0);
  expect(abortedLease.committedCalls, 0);
  expect(abortedLease.abortedCalls, 1);
  expect(root.isDisposed, isFalse);
  expect(root.readDocument().layers.single.elements, hasLength(1));
  expect(root.diagnosticRecords.map((record) => record.details), [
    {'operation': 'runtimeMutation'},
    {'operation': 'runtimeMutation'},
    {'operation': 'dispose'},
    {'operation': 'nestedResolverCallback'},
    {'operation': 'runtimeMutation'},
    {'operation': 'runtimeMutation'},
    {'operation': 'dispose'},
    {'operation': 'nestedResolverCallback'},
  ]);
}

void _expectUnhandledLeaseCallbackRejections() {
  for (final terminal in _LeaseTerminal.values) {
    for (final operation in _leaseReentrantOperations) {
      _expectUnhandledLeaseCallbackRejection(terminal, operation);
    }
  }
}

// The terminal/error-kind matrix shares one setup so applied and unapplied
// finality cannot silently lose parity.
// ignore: halstead-volume
Future<void> _expectThrowingLeaseCallbacksAreContained() async {
  for (final terminal in _LeaseTerminal.values) {
    for (final thrown in <Object>[
      StateError('must not appear in diagnostics'),
      const FormatException('must not appear in diagnostics'),
      _OrdinaryThrownLeaseObject(),
    ]) {
      final lease = _DrawLease();
      final effectBatches = <List<CommitDeliveryEffect>>[];
      late RuntimeRoot root;
      root = runtimeRootWithCommittedDocumentSeed(
        CanvasDocument(),
        config: CanvasRuntimeConfig(
          diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
          commitResolver: (_) => _leaseResolution(terminal, lease),
        ),
        commitEffectObserver: effectBatches.add,
      );
      final actions = <CanvasActionCommitted>[];
      final subscription = root.actions.listen(actions.add);
      _configureThrowingLeaseCallback(terminal, lease, thrown);

      try {
        _drawPencil(root);
        await Future<void>.delayed(Duration.zero);

        _expectThrowingLeaseCallbackOutcome(
          scenario: (
            root: root,
            lease: lease,
            actions: actions,
            effectBatches: effectBatches,
          ),
          terminal: terminal,
          thrown: thrown,
        );
        expect(root.generateElementId(), isNotNull);
      } finally {
        await subscription.cancel();
        root.dispose();
      }
    }
  }
}

void _configureThrowingLeaseCallback(
  _LeaseTerminal terminal,
  _DrawLease lease,
  Object thrown,
) {
  void callback() => _throwLeaseValue(thrown);
  switch (terminal) {
    case _LeaseTerminal.committed:
      lease.onCommitted = callback;
    case _LeaseTerminal.aborted:
      lease.onAborted = callback;
  }
}

// One assertion block keeps terminal count, bounded diagnostics, and delivery
// outcome coupled for each matrix entry.
// ignore: halstead-volume
void _expectThrowingLeaseCallbackOutcome({
  required _ThrowingLeaseScenario scenario,
  required _LeaseTerminal terminal,
  required Object thrown,
}) {
  final root = scenario.root;
  final lease = scenario.lease;
  final reason = '${terminal.name}/${thrown.runtimeType}';
  expect(lease.committedCalls, terminal == _LeaseTerminal.committed ? 1 : 0);
  expect(lease.abortedCalls, terminal == _LeaseTerminal.aborted ? 1 : 0);
  expect(root.diagnosticRecords, hasLength(1), reason: reason);
  final diagnostic = root.diagnosticRecords.single;
  expect(
    diagnostic.code,
    const DiagnosticCode.interaction(
      InteractionDiagnosticCode.resolverCallbackFailed,
    ),
    reason: reason,
  );
  expect(diagnostic.severity, DiagnosticSeverity.warning, reason: reason);
  expect(diagnostic.source, DiagnosticSource.interaction, reason: reason);
  expect(diagnostic.details, {
    'operation': terminal == _LeaseTerminal.committed
        ? 'commitLeaseCommitted'
        : 'commitLeaseAborted',
    'errorKind': thrown is Error
        ? 'error'
        : thrown is Exception
        ? 'exception'
        : 'object',
  }, reason: reason);
  expect(diagnostic.path, isNull, reason: reason);
  expect(diagnostic.revision, isNull, reason: reason);
  expect(diagnostic.sessionId, isNull, reason: reason);
  expect(diagnostic.correlationId, isNull, reason: reason);

  final committed = terminal == _LeaseTerminal.committed;
  expect(root.state.value.summary.elementCount, committed ? 1 : 0);
  expect(scenario.actions, hasLength(committed ? 1 : 0), reason: reason);
  expect(scenario.effectBatches, hasLength(committed ? 1 : 0), reason: reason);
}

void _throwLeaseValue(Object value) {
  // Ordinary objects are part of the bounded error-kind contract.
  // ignore: only_throw_errors
  throw value;
}

void _expectUnhandledLeaseCallbackRejection(
  _LeaseTerminal terminal,
  _LeaseReentrantOperation operation,
) {
  late RuntimeRoot root;
  final lease = _DrawLease();
  root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    config: CanvasRuntimeConfig(
      diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
      commitResolver: (_) => _leaseResolution(terminal, lease),
    ),
  );
  _configureUnhandledLeaseCallback(terminal, lease, root, operation);

  _drawPencil(root);

  _expectUnhandledLeaseCallbackOutcome(root, lease, terminal, operation);
  root.dispose();
}

CanvasCommitResolution _leaseResolution(
  _LeaseTerminal terminal,
  _DrawLease lease,
) => switch (terminal) {
  _LeaseTerminal.committed => CanvasCommitAccept(lease: lease),
  _LeaseTerminal.aborted => CanvasMoveCommitAccept(
    delta: const Offset(1, 0),
    lease: lease,
  ),
};

void _configureUnhandledLeaseCallback(
  _LeaseTerminal terminal,
  _DrawLease lease,
  RuntimeRoot root,
  _LeaseReentrantOperation operation,
) {
  switch (terminal) {
    case _LeaseTerminal.committed:
      lease.onCommitted = () => operation.invoke(root);
    case _LeaseTerminal.aborted:
      lease.onAborted = () => operation.invoke(root);
  }
}

void _expectUnhandledLeaseCallbackOutcome(
  RuntimeRoot root,
  _DrawLease lease,
  _LeaseTerminal terminal,
  _LeaseReentrantOperation operation,
) {
  expect(
    root.isDisposed,
    isFalse,
    reason: '${terminal.name}/${operation.name}',
  );
  expect(root.diagnosticRecords.single.details, {
    'operation': operation.diagnosticOperation,
  });
  switch (terminal) {
    case _LeaseTerminal.committed:
      expect(lease.committedCalls, 1);
      expect(lease.abortedCalls, 0);
      expect(root.readDocument().layers.single.elements, hasLength(1));
    case _LeaseTerminal.aborted:
      expect(lease.committedCalls, 0);
      expect(lease.abortedCalls, 1);
      expect(root.readDocument().layers, isEmpty);
  }
}

void _catchLeaseReentrantOperations(RuntimeRoot root) {
  final operations = [
    for (final operation in _leaseReentrantOperations)
      () => operation.invoke(root),
  ];
  for (final operation in operations) {
    try {
      operation();
    }
    // ignore: avoid_catching_errors, reason: The callback guard must permit a host to contain one rejected call.
    on ResolverCallbackRejection {
      continue;
    }
    fail('Expected lease callback operation to be rejected.');
  }
}

enum _LeaseTerminal { committed, aborted }

final class _OrdinaryThrownLeaseObject {
  @override
  String toString() => 'must not appear in diagnostics';
}

typedef _CaughtLeaseScenario = ({
  RuntimeRoot root,
  _DrawLease committedLease,
  _DrawLease abortedLease,
});

typedef _ThrowingLeaseScenario = ({
  RuntimeRoot root,
  _DrawLease lease,
  List<CanvasActionCommitted> actions,
  List<List<CommitDeliveryEffect>> effectBatches,
});

final _leaseReentrantOperations = <_LeaseReentrantOperation>[
  _LeaseReentrantOperation('id', 'runtimeMutation', (root) {
    root.generateElementId();
  }),
  _LeaseReentrantOperation('mutation', 'runtimeMutation', (root) {
    root.selection.clearSelection();
  }),
  _LeaseReentrantOperation('dispose', 'dispose', (root) {
    root.dispose();
  }),
  _LeaseReentrantOperation('nestedResolver', 'nestedResolverCallback', (root) {
    root.runResolverCallback(() => const CanvasCommitCancel());
  }),
];

final class _LeaseReentrantOperation {
  const _LeaseReentrantOperation(
    this.name,
    this.diagnosticOperation,
    this.invoke,
  );

  final String name;
  final String diagnosticOperation;
  final void Function(RuntimeRoot root) invoke;
}

// Keeping the five route variants together avoids duplicate resolver setup and
// preserves the required parity between their retained public facts.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _verifyUnifiedDrawCommitRequests() async {
  final requests = <CanvasDrawCommitRequest>[];
  final leases = <_DrawLease>[];
  final committedSnapshots = <({int documentRevision, int actionCount})>[];
  final actions = <CanvasActionCommitted>[];
  var resolverCalls = 0;
  const expectedContexts = [
    _DrawRequestContext(
      summary: CanvasDocumentSummary(
        elementCount: 0,
        layerCount: 0,
        resourceCount: 0,
      ),
      documentRevision: 0,
      selectedElementIdsBefore: [],
    ),
    _DrawRequestContext(
      summary: CanvasDocumentSummary(
        elementCount: 1,
        layerCount: 1,
        resourceCount: 0,
      ),
      documentRevision: 1,
      selectedElementIdsBefore: [],
    ),
    _DrawRequestContext(
      summary: CanvasDocumentSummary(
        elementCount: 2,
        layerCount: 1,
        resourceCount: 0,
      ),
      documentRevision: 2,
      selectedElementIdsBefore: [],
    ),
    _DrawRequestContext(
      summary: CanvasDocumentSummary(
        elementCount: 3,
        layerCount: 1,
        resourceCount: 0,
      ),
      documentRevision: 3,
      selectedElementIdsBefore: [],
    ),
    _DrawRequestContext(
      summary: CanvasDocumentSummary(
        elementCount: 4,
        layerCount: 1,
        resourceCount: 0,
      ),
      documentRevision: 4,
      selectedElementIdsBefore: [],
    ),
  ];
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    config: CanvasRuntimeConfig(
      commitResolver: (request) {
        resolverCalls += 1;
        final draw = request as CanvasDrawCommitRequest;
        requests.add(draw);
        final lease = _DrawLease(
          onCommitted: () {
            committedSnapshots.add((
              documentRevision: root.state.value.revisions.document,
              actionCount: actions.length,
            ));
          },
        );
        leases.add(lease);
        return CanvasCommitAccept(lease: lease);
      },
    ),
  );
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  _expectDrawRuntimeContext(root, expectedContexts[0]);
  _drawPencil(root);
  _expectDrawRuntimeContext(root, expectedContexts[1]);
  _drawMarker(root);
  _expectDrawRuntimeContext(root, expectedContexts[2]);
  _drawFirstPointerDragLine(root);
  _expectCleanDrawDelivery(root);
  expect(requests, hasLength(3));
  expect(resolverCalls, 3);
  expect(leases, hasLength(3));
  expect(leases[2].committedCalls, 1);
  expect(leases[2].abortedCalls, 0);
  _expectDrawRuntimeContext(root, expectedContexts[3]);
  _drawLine(root, firstTapTimestampMs: 13, endpointTimestampMs: 14);
  _expectDrawRuntimeContext(root, expectedContexts[4]);
  _drawDotLine(root);
  await Future<void>.delayed(Duration.zero);

  _expectRetainedDrawRequests(requests);
  expect(resolverCalls, 5);
  expect(actions, hasLength(5));
  final installedDocument = root.readDocument();
  _expectPencil(installedDocument, actions[0]);
  _expectMarker(installedDocument, actions[1]);
  _expectDrawLineAction(
    installedDocument,
    actions[2],
    elementId: CanvasElementId('e2'),
    timestampMs: 12,
    start: const Offset(10, 20),
    end: const Offset(14, 25),
    color: const Color(0xFF778899),
    thickness: 4,
    opacity: 1,
  );
  _expectDrawLineAction(
    installedDocument,
    actions[3],
    elementId: CanvasElementId('e3'),
    timestampMs: 14,
    start: const Offset(1, 2),
    end: const Offset(3, 4),
    color: const Color(0xFF778899),
    thickness: 4,
    opacity: 1,
  );
  _expectDrawLineAction(
    installedDocument,
    actions[4],
    elementId: CanvasElementId('e4'),
    timestampMs: 16,
    start: const Offset(5, 6),
    end: const Offset(5, 6),
    color: const Color(0xFF778899),
    thickness: 4,
    opacity: 1,
  );
  expect(committedSnapshots, [
    (documentRevision: 1, actionCount: 0),
    (documentRevision: 2, actionCount: 1),
    (documentRevision: 3, actionCount: 2),
    (documentRevision: 4, actionCount: 3),
    (documentRevision: 5, actionCount: 4),
  ]);
  expect(leases.every((lease) => lease.committedCalls == 1), isTrue);
  expect(leases.every((lease) => lease.abortedCalls == 0), isTrue);

  root.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(
        id: CanvasElementId('after-request-mutation'),
        size: const Size(1, 1),
      ),
      layerId: CanvasLayerId('default-layer'),
    );
  });
  root.selection.setSelection([CanvasElementId('after-request-mutation')]);
  _expectRetainedDrawRequests(requests);
  for (var index = 0; index < requests.length; index += 1) {
    _expectDrawRequestContext(requests[index], expectedContexts[index]);
    expect(
      () => requests[index].selectedElementIdsBefore.add(
        CanvasElementId('unexpected'),
      ),
      throwsUnsupportedError,
    );
  }
}

// The complete literal matrix is clearer than splitting one retained-request
// contract into route-specific helpers just to lower metrics.
// ignore: halstead-volume, source-lines-of-code
void _expectRetainedDrawRequests(List<CanvasDrawCommitRequest> requests) {
  expect(requests, hasLength(5));
  _expectStrokeDrawRequest(
    requests[0],
    elementId: CanvasElementId('e0'),
    tool: CanvasDrawTool.pencil,
    elementIndex: 0,
    createsLayer: true,
    points: const [Offset.zero, Offset(2, 3), Offset(4, 5)],
    color: const Color(0xFF112233),
    thickness: 3,
    opacity: 1,
  );
  _expectStrokeDrawRequest(
    requests[1],
    elementId: CanvasElementId('e1'),
    tool: CanvasDrawTool.marker,
    elementIndex: 1,
    createsLayer: false,
    points: const [Offset.zero, Offset(1, 1)],
    color: const Color(0xFF445566),
    thickness: 12,
    opacity: 0.4,
  );
  _expectLineDrawRequest(
    requests[2],
    elementId: CanvasElementId('e2'),
    tool: CanvasDrawTool.line,
    elementIndex: 2,
    createsLayer: false,
    start: const Offset(10, 20),
    end: const Offset(14, 25),
    color: const Color(0xFF778899),
    thickness: 4,
    opacity: 1,
  );
  _expectLineDrawRequest(
    requests[3],
    elementId: CanvasElementId('e3'),
    tool: CanvasDrawTool.line,
    elementIndex: 3,
    createsLayer: false,
    start: const Offset(1, 2),
    end: const Offset(3, 4),
    color: const Color(0xFF778899),
    thickness: 4,
    opacity: 1,
  );
  _expectLineDrawRequest(
    requests[4],
    elementId: CanvasElementId('e4'),
    tool: CanvasDrawTool.line,
    elementIndex: 4,
    createsLayer: false,
    start: const Offset(5, 6),
    end: const Offset(5, 6),
    color: const Color(0xFF778899),
    thickness: 4,
    opacity: 1,
  );
}

void _expectDrawRuntimeContext(RuntimeRoot root, _DrawRequestContext expected) {
  final summary = root.state.value.summary;
  expect(summary.elementCount, expected.summary.elementCount);
  expect(summary.layerCount, expected.summary.layerCount);
  expect(summary.resourceCount, expected.summary.resourceCount);
  expect(root.state.value.revisions.document, expected.documentRevision);
  expect(root.selection.selectedElementIds, expected.selectedElementIdsBefore);
}

void _expectDrawRequestContext(
  CanvasDrawCommitRequest request,
  _DrawRequestContext expected,
) {
  expect(request.documentSummary, expected.summary);
  expect(request.documentRevision, expected.documentRevision);
  expect(request.selectedElementIdsBefore, expected.selectedElementIdsBefore);
}

final class _DrawRequestContext {
  const _DrawRequestContext({
    required this.summary,
    required this.documentRevision,
    required this.selectedElementIdsBefore,
  });

  final CanvasDocumentSummary summary;
  final int documentRevision;
  final List<CanvasElementId> selectedElementIdsBefore;
}

// Named literal fields keep this public entry contract readable at each route.
// ignore: number-of-parameters
void _expectStrokeDrawRequest(
  CanvasDrawCommitRequest request, {
  required CanvasElementId elementId,
  required CanvasDrawTool tool,
  required int elementIndex,
  required bool createsLayer,
  required List<Offset> points,
  required Color color,
  required double thickness,
  required double opacity,
}) {
  _expectDrawRequestEnvelope(
    request,
    elementType: CanvasStrokeElement,
    elementId: elementId,
    tool: tool,
    elementIndex: elementIndex,
    createsLayer: createsLayer,
  );
  final stroke = request.entry.element as CanvasStrokeElement;
  expect(stroke.kind, CanvasElementKind.stroke);
  expect(stroke.points, points);
  expect(stroke.color, color);
  expect(stroke.thickness, thickness);
  expect(stroke.opacity, opacity);
}

// Named literal fields keep this public entry contract readable at each route.
// ignore: number-of-parameters
void _expectLineDrawRequest(
  CanvasDrawCommitRequest request, {
  required CanvasElementId elementId,
  required CanvasDrawTool tool,
  required int elementIndex,
  required bool createsLayer,
  required Offset start,
  required Offset end,
  required Color color,
  required double thickness,
  required double opacity,
}) {
  _expectDrawRequestEnvelope(
    request,
    elementType: CanvasLineElement,
    elementId: elementId,
    tool: tool,
    elementIndex: elementIndex,
    createsLayer: createsLayer,
  );
  final line = request.entry.element as CanvasLineElement;
  expect(line.kind, CanvasElementKind.line);
  expect(line.start, start);
  expect(line.end, end);
  expect(line.color, color);
  expect(line.thickness, thickness);
  expect(line.opacity, opacity);
}

// This single envelope assertion keeps all common public element facts together.
// ignore: number-of-parameters
void _expectDrawRequestEnvelope(
  CanvasDrawCommitRequest request, {
  required Type elementType,
  required CanvasElementId elementId,
  required CanvasDrawTool tool,
  required int elementIndex,
  required bool createsLayer,
}) {
  final element = request.entry.element;
  expect(element.runtimeType, elementType);
  expect(element.id, elementId);
  expect(element.revision, 0);
  expect(element.transform, CanvasTransform.identity);
  expect(element.hitPadding, 0);
  expect(element.isVisible, isTrue);
  expect(element.isSelectable, isTrue);
  expect(element.isLocked, isFalse);
  expect(element.isDeletable, isTrue);
  expect(element.isTransformable, isTrue);
  expect(element.metadata, const CanvasMetadata.empty());
  expect(request.entry.layerId, CanvasLayerId('default-layer'));
  expect(request.entry.elementIndex, elementIndex);
  expect(request.layerIndex, 0);
  expect(request.tool, tool);
  expect(request.createsLayer, createsLayer);
}

Future<void> _verifyCancelledDrawCommit() async {
  CanvasDrawCommitRequest? request;
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    config: CanvasRuntimeConfig(
      commitResolver: (candidate) {
        request = candidate as CanvasDrawCommitRequest;
        return const CanvasCommitCancel();
      },
    ),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });
  final beforeDocument = root.readDocument();
  final beforeSelection = root.selectedElementIds;

  _drawPencil(root);
  await Future<void>.delayed(Duration.zero);

  expect(request, isNotNull);
  expect(root.readDocument(), same(beforeDocument));
  expect(root.selectedElementIds, beforeSelection);
  expect(root.state.value.summary.elementCount, 0);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
  expect(actions, isEmpty);
  expect(root.generateElementId(), CanvasElementId('e0'));
}

// Each draw variant must share the same real callback observations; splitting
// the matrix would obscure a route-specific cleanup/delivery regression.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _verifyDrawRouteDeliveryCleanup() async {
  for (final route
      in <
        ({
          RuntimeNonTextRoute route,
          void Function(RuntimeRoot) start,
          void Function(RuntimeRoot) finish,
        })
      >[
        (
          route: RuntimeNonTextRoute.drawStroke,
          start: _startPencilDeliveryProbe,
          finish: _finishPencilDeliveryProbe,
        ),
        (
          route: RuntimeNonTextRoute.drawStroke,
          start: _startMarkerDeliveryProbe,
          finish: _finishMarkerDeliveryProbe,
        ),
        (
          route: RuntimeNonTextRoute.drawLine,
          start: _startLineDeliveryProbe,
          finish: _finishLineDeliveryProbe,
        ),
      ]) {
    final trace = <String>[];
    var terminalDelivery = false;
    late RuntimeRoot root;
    root = runtimeRootWithCommittedDocumentSeed(
      CanvasDocument(),
      commitEffectObserver: (effects) {
        if (!terminalDelivery) return;
        _expectCleanDrawDelivery(root);
        _expectMergedDrawRepaint(effects);
        trace.add('observer');
      },
    );
    final surface = Object();
    root.attachSurface(surface);
    route.start(root);
    root.surfaceFrameSignal.addListener(() {
      if (!terminalDelivery) return;
      _expectCleanDrawDelivery(root);
      final frame = root.surfaceFrameSignal.value;
      expect(frame?.mainCanvas, isTrue);
      expect(frame?.overlayCanvas, isTrue);
      trace.add('frame');
    });
    root.state.addListener(() {
      if (!terminalDelivery) return;
      _expectCleanDrawDelivery(root);
      trace.add('state');
    });
    final subscription = root.actions.listen((_) {
      _expectCleanDrawDelivery(root);
      trace.add('action');
    });
    terminalDelivery = true;
    final events = <RuntimeRouteTemporalEvent>[];
    RuntimeRoot.observeRouteTemporalEvents((event) {
      events.add(event);
      _recordDrawRouteLifecycleTrace(event, route.route, trace);
    }, () => route.finish(root));
    expect(trace, [
      'prepared',
      'cleanup',
      'effects',
      'delivery',
      'frame',
      'state',
      'action',
      'observer',
    ]);
    _expectDrawRouteLifecycle(events, route.route);
    await subscription.cancel();
    terminalDelivery = false;
    root.detachSurface(surface);
    root.dispose();
  }
}

void _recordDrawRouteLifecycleTrace(
  RuntimeRouteTemporalEvent event,
  RuntimeNonTextRoute route,
  List<String> trace,
) {
  if (event.route != route) return;
  switch (event.kind) {
    case RuntimeRouteTemporalEventKind.preparedApplyReturned:
      trace.add('prepared');
    case RuntimeRouteTemporalEventKind.routeCleanupCompleted:
      trace.add('cleanup');
    case RuntimeRouteTemporalEventKind.cleanupEffectsAugmented:
      trace.add('effects');
    case RuntimeRouteTemporalEventKind.commonDeliveryEntered:
      trace.add('delivery');
    default:
      break;
  }
}

void _expectDrawRouteLifecycle(
  List<RuntimeRouteTemporalEvent> events,
  RuntimeNonTextRoute route,
) {
  expect(
    events.where((event) => event.route == route).map((event) => event.kind),
    [
      RuntimeRouteTemporalEventKind.preparedApplyReturned,
      RuntimeRouteTemporalEventKind.routeCleanupCompleted,
      RuntimeRouteTemporalEventKind.cleanupEffectsAugmented,
      RuntimeRouteTemporalEventKind.commonDeliveryEntered,
    ],
  );
}

void _startPencilDeliveryProbe(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle.defaultStyle);
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(2, 3)),
  );
}

void _finishPencilDeliveryProbe(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(4, 5)),
  );
}

void _startMarkerDeliveryProbe(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.marker));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
}

void _finishMarkerDeliveryProbe(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(2, 3)),
  );
}

void _startLineDeliveryProbe(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.line));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.up, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(2, 3)),
  );
}

void _finishLineDeliveryProbe(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(2, 3)),
  );
}

void _expectCleanDrawDelivery(RuntimeRoot root) {
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
}

void _expectMergedDrawRepaint(List<CommitDeliveryEffect> effects) {
  final repaint = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isTrue);
}

Future<void> _verifyDrawCommitDelivery() async {
  final scenario = _scenario();

  _drawPencil(scenario.root);
  await _expectDeliveredActionCount(scenario, expectedDocumentRevisions: [1]);
  _expectLatestCommitRepaintsMainAndOverlay(scenario);

  _drawMarker(scenario.root);
  await _expectDeliveredActionCount(
    scenario,
    expectedDocumentRevisions: [1, 2],
  );
  _expectLatestCommitRepaintsMainAndOverlay(scenario);

  _drawLine(scenario.root);
  await _expectDeliveredActionCount(
    scenario,
    expectedDocumentRevisions: [1, 2, 3],
  );
  _expectLatestCommitRepaintsMainAndOverlay(scenario);
  _expectPencil(scenario.root.readDocument(), scenario.actions[0]);
  _expectMarker(scenario.root.readDocument(), scenario.actions[1]);
  _expectLine(scenario.root.readDocument(), scenario.actions[2]);
  _expectAcceptedDrawRouteIdOrder(scenario);
}

void _expectAcceptedDrawRouteIdOrder(_DrawScenario scenario) {
  expect(scenario.actions.map((action) => action.elementIds.single), [
    CanvasElementId('e0'),
    CanvasElementId('e1'),
    CanvasElementId('e2'),
  ]);
  expect(scenario.root.generateElementId(), CanvasElementId('e3'));
}

Future<void> _expectDeliveredActionCount(
  _DrawScenario scenario, {
  required List<int> expectedDocumentRevisions,
}) async {
  await Future<void>.delayed(Duration.zero);
  expect(scenario.actions, hasLength(expectedDocumentRevisions.length));
  expect(scenario.effectBatches, hasLength(expectedDocumentRevisions.length));
  expect(
    scenario.actionStates.map((state) => state.revisions.document),
    expectedDocumentRevisions,
  );
}

void _expectLatestCommitRepaintsMainAndOverlay(_DrawScenario scenario) {
  final repaint = scenario.effectBatches.last
      .whereType<RepaintDeliveryEffect>()
      .single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isTrue);
}

void _drawPencil(RuntimeRoot root, {int? timestampMs = 10}) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.pencil,
      color: const Color(0xFF112233),
      pencilThickness: 3,
    ),
  );
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(2, 3)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(4, 5), timestampMs),
  );
}

void _drawMarker(RuntimeRoot root) {
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.marker,
      color: const Color(0xFF445566),
      markerThickness: 12,
      markerOpacity: 0.4,
    ),
  );
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(1, 1), 11),
  );
}

void _drawFirstPointerDragLine(RuntimeRoot root) {
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF778899),
      lineThickness: 4,
    ),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(10, 20)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(12, 22)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(14, 25), 12),
  );
}

void _drawLine(
  RuntimeRoot root, {
  int firstTapTimestampMs = 12,
  int endpointTimestampMs = 13,
}) {
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF778899),
      lineThickness: 4,
    ),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 2)),
  );
  root.handlePointer(
    _pointer(
      CanvasPointerLifecyclePhase.up,
      const Offset(1, 2),
      firstTapTimestampMs,
    ),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(3, 4)),
  );
  root.handlePointer(
    _pointer(
      CanvasPointerLifecyclePhase.up,
      const Offset(3, 4),
      endpointTimestampMs,
    ),
  );
}

void _drawDotLine(RuntimeRoot root) {
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF778899),
      lineThickness: 4,
    ),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(5, 6)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(5, 6), 15),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(5, 6)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(5, 6), 16),
  );
}

void _expectPencil(CanvasDocument document, CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawPencil);
  expect(action.timestampMs, 10);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.pencil);
  expect(payload.color, const Color(0xFF112233));
  expect(payload.thickness, 3);
  expect(payload.opacity, 1);
  expect(payload.pointCount, 3);

  final stroke = _element(document, action) as CanvasStrokeElement;
  expect(stroke.points, const [Offset.zero, Offset(2, 3), Offset(4, 5)]);
  expect(stroke.color, const Color(0xFF112233));
  expect(stroke.thickness, 3);
  expect(stroke.opacity, 1);
}

void _expectMarker(CanvasDocument document, CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawMarker);
  expect(action.timestampMs, 11);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.marker);
  expect(payload.color, const Color(0xFF445566));
  expect(payload.thickness, 12);
  expect(payload.opacity, 0.4);
  expect(payload.pointCount, 2);

  final stroke = _element(document, action) as CanvasStrokeElement;
  expect(stroke.points, const [Offset.zero, Offset(1, 1)]);
  expect(stroke.color, const Color(0xFF445566));
  expect(stroke.thickness, 12);
  expect(stroke.opacity, 0.4);
}

void _expectLine(CanvasDocument document, CanvasActionCommitted action) {
  _expectDrawLineAction(
    document,
    action,
    elementId: CanvasElementId('e2'),
    timestampMs: 13,
    start: const Offset(1, 2),
    end: const Offset(3, 4),
    color: const Color(0xFF778899),
    thickness: 4,
    opacity: 1,
  );
}

// The installed action and its element share one externally visible contract.
// ignore: number-of-parameters
void _expectDrawLineAction(
  CanvasDocument document,
  CanvasActionCommitted action, {
  required CanvasElementId elementId,
  required int timestampMs,
  required Offset start,
  required Offset end,
  required Color color,
  required double thickness,
  required double opacity,
}) {
  expect(action.type, CanvasActionType.drawLine);
  expect(action.elementIds, [elementId]);
  expect(action.timestampMs, timestampMs);
  final payload = action.payload as CanvasDrawLineActionPayload;
  expect(payload.color, color);
  expect(payload.thickness, thickness);
  expect(payload.opacity, opacity);
  expect(payload.startWorld, start);
  expect(payload.endWorld, end);

  final line = _element(document, action) as CanvasLineElement;
  expect(line.start, start);
  expect(line.end, end);
  expect(line.color, color);
  expect(line.thickness, thickness);
  expect(line.opacity, opacity);
}

CanvasElement _element(CanvasDocument document, CanvasActionCommitted action) {
  return document.layers.single.elements.singleWhere(
    (element) => element.id == action.elementIds.single,
  );
}

Future<void> _verifyDrawDeliveryFailureRollback() async {
  final scenario = _scenario();
  final before = _startPencilPreview(scenario.root);

  _expectInvalidStrokeCommitRejected(scenario.root);
  await Future<void>.delayed(Duration.zero);

  _expectFailedDrawDeliveryRollback(scenario, before);
  expect(scenario.root.generateElementId(), CanvasElementId('e0'));
  await _expectFailureDoesNotAdvanceActionTimestamp(scenario);
}

CanvasRuntimeState _startPencilPreview(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle.defaultStyle);

  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  final state = root.state.value;
  expect(root.preview, isA<CanvasPencilStrokePreview>());

  return state;
}

void _expectInvalidStrokeCommitRejected(RuntimeRoot root) {
  expect(
    () => root.deliverDrawStrokeCommitForTesting(
      _emptyStrokeCommitIntent(),
      timestampHintMs: 20,
    ),
    throwsA(isA<CanvasDataException>()),
  );
}

void _expectFailedDrawDeliveryRollback(
  _DrawScenario scenario,
  CanvasRuntimeState before,
) {
  expect(scenario.actions, isEmpty);
  expect(
    scenario.root.state.value.revisions.document,
    before.revisions.document,
  );
  expect(scenario.root.preview, isA<CanvasNoPreview>());
}

Future<void> _expectFailureDoesNotAdvanceActionTimestamp(
  _DrawScenario scenario,
) async {
  _drawPencil(scenario.root, timestampMs: null);
  await Future<void>.delayed(Duration.zero);
  expect(scenario.actions.single.timestampMs, 0);
  expect(scenario.actions.single.elementIds, [CanvasElementId('e1')]);
}

Future<void> _verifyLineDeliveryFailureRollback() async {
  final scenario = _scenario();
  final before = _startPendingLinePreview(scenario.root);

  expect(
    () => scenario.root.deliverDrawLineCommitForTesting(
      _invalidLineCommitIntent(),
      timestampHintMs: 20,
    ),
    throwsA(isA<CanvasDataException>()),
  );
  await Future<void>.delayed(Duration.zero);

  _expectFailedLineDeliveryRollback(scenario, before);
  await _expectFailedLineLeavesTimestampUnadvanced(scenario);
}

void _expectFailedLineDeliveryRollback(
  _DrawScenario scenario,
  CanvasRuntimeState before,
) {
  expect(scenario.actions, isEmpty);
  expect(
    scenario.root.state.value.revisions.document,
    before.revisions.document,
  );
  expect(scenario.root.preview, isA<CanvasNoPreview>());
  expect(scenario.root.generateElementId(), CanvasElementId('e0'));
}

Future<void> _expectFailedLineLeavesTimestampUnadvanced(
  _DrawScenario scenario,
) async {
  scenario.root.deliverDrawLineCommitForTesting(
    _validLineCommitIntent(),
    timestampHintMs: null,
  );
  await Future<void>.delayed(Duration.zero);
  // The pending-line preview has already accepted baseline timestamp zero.
  expect(scenario.actions.single.timestampMs, 1);
  expect(scenario.actions.single.elementIds, [CanvasElementId('e1')]);
}

CanvasRuntimeState _startPendingLinePreview(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(tool: CanvasDrawTool.line, lineThickness: 4),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 2)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(1, 2)),
  );
  expect(root.preview, isA<CanvasPendingLineStartPreview>());

  return root.state.value;
}

DrawStrokeCommitIntent _emptyStrokeCommitIntent() {
  return DrawStrokeCommitIntent(
    sessionId: const PointerSessionId(100),
    pointerToken: const PointerSessionToken(100),
    tool: CanvasDrawTool.pencil,
    points: const [],
    color: const Color(0xFF112233),
    thickness: 3,
    opacity: 1,
  );
}

DrawLineCommitIntent _invalidLineCommitIntent() {
  return const DrawLineCommitIntent(
    sessionId: PointerSessionId(100),
    pointerToken: PointerSessionToken(100),
    startWorld: Offset.zero,
    endWorld: Offset(1, 1),
    color: Color(0xFF112233),
    thickness: 0,
    opacity: 1,
  );
}

DrawLineCommitIntent _validLineCommitIntent() {
  return const DrawLineCommitIntent(
    sessionId: PointerSessionId(101),
    pointerToken: PointerSessionToken(101),
    startWorld: Offset.zero,
    endWorld: Offset(1, 1),
    color: Color(0xFF112233),
    thickness: 4,
    opacity: 1,
  );
}

Future<void> _verifyRuntimeRouteIdAdmissionWork() async {
  final setup = _createSupportedPrefixRuntime();
  addTearDown(setup.root.dispose);
  _expectSupportedPrefixReset(setup.resetWork);
  _verifyRepeatedFailedRouteReads(setup.root);
  await _verifyAcceptedRouteReads(setup);
  await Future<void>.delayed(Duration.zero);
}

_RouteWorkSetup _createSupportedPrefixRuntime() {
  final delivery = _DrawWorkDeliveryProbe();
  final requests = <CanvasDrawCommitRequest>[];
  late RuntimeRoot root;
  final resetWork = observeIdAdmissionWork(() {
    root = runtimeRootWithCommittedDocumentSeed(
      _supportedPrefixDocument(),
      config: CanvasRuntimeConfig(
        commitResolver: (request) {
          requests.add(request as CanvasDrawCommitRequest);
          return CanvasCommitAccept(lease: _DrawLease());
        },
      ),
      commitEffectObserver: (effects) => delivery.observeEffects(effects),
    );
  });

  return (
    root: root,
    resetWork: resetWork,
    delivery: delivery,
    requests: requests,
  );
}

void _expectSupportedPrefixReset(IdAdmissionWorkRecorder work) {
  _expectIdAdmissionPhase(
    work,
    phase: IdAdmissionWorkPhase.reset,
    expected: const {
      IdAdmissionWorkKind.inputVisit: 200000,
      IdAdmissionWorkKind.cursorProbe: 200001,
      IdAdmissionWorkKind.collision: 200000,
      IdAdmissionWorkKind.advance: 200000,
    },
  );
}

void _verifyRepeatedFailedRouteReads(RuntimeRoot root) {
  for (var attempt = 0; attempt < 2; attempt += 1) {
    final strokeWork = observeIdAdmissionWork(() {
      _expectInvalidStrokeCommitRejected(root);
    });
    _expectReadOnlyRouteCandidate(strokeWork);

    _startPendingLinePreview(root);
    final lineWork = observeIdAdmissionWork(() {
      expect(
        () => root.deliverDrawLineCommitForTesting(
          _invalidLineCommitIntent(),
          timestampHintMs: 20,
        ),
        throwsA(isA<CanvasDataException>()),
      );
    });
    _expectReadOnlyRouteCandidate(lineWork);
    expect(root.preview, isA<CanvasNoPreview>());
  }
}

// One accepted draw trace keeps all real owner seams together; splitting it
// would make callback-multiplied work indistinguishable from fixture plumbing.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _verifyAcceptedRouteReads(_RouteWorkSetup setup) async {
  final root = setup.root;
  final delivery = setup.delivery;
  final candidateEvents = <StoreSparseCandidateEvent>[];
  final deliveryEvents = <RuntimeCommonDeliveryEvent>[];
  final beforeProjectionBuilds = root.projectionBuildCount;
  final surfaceToken = Object();
  final releasedResourceIds = <Set<CanvasResourceId>>[];
  root.attachSurface(surfaceToken);
  root.installSurfaceResourceSession(
    surfaceToken,
    SurfaceResourceSession(
      resolver: null,
      mutationGuard: root,
      releaseRetainedResources: (ids) => releasedResourceIds.add(ids),
    ),
  );
  root.surfaceFrameSignal.addListener(delivery.observeRootFrame);
  root.state.addListener(delivery.observeState);
  final actionSubscription = root.actions.listen(delivery.observeAction);
  CommitSealedDeliveryWork observeDeliveryWork(void Function() operation) {
    late CommitSealedDeliveryWork work;
    CommitApplier.observeSealedDeliveryWork((observed) => work = observed, () {
      RuntimeRoot.observeCommonDeliveryEvents((event) {
        deliveryEvents.add(event);
        delivery.observeCommonDeliveryEvent(event);
      }, operation);
    });
    return work;
  }

  late CommitSealedDeliveryWork pencilDeliveryWork;
  final layerWork = <LayerTableWorkEvent>[];
  final pencilWork = observeIdAdmissionWork(() {
    LayerTable.observeWork(layerWork.add, () {
      CommittedDocument.observeSparseCandidateEvents(candidateEvents.add, () {
        pencilDeliveryWork = observeDeliveryWork(() => _drawPencil(root));
      });
    });
  });
  _expectReadOnlyRouteCandidate(pencilWork);
  _expectAcceptedRouteAdmission(pencilWork);
  expect(setup.requests[0].entry.layerId, CanvasLayerId('work-layer'));
  expect(setup.requests[0].entry.elementIndex, 195905);
  expect(setup.requests[0].createsLayer, isFalse);
  expect(
    layerWork.where(
      (event) => event == LayerTableWorkEvent.placementLocationRead,
    ),
    hasLength(2),
  );
  expect(
    layerWork.where((event) => event == LayerTableWorkEvent.placementRowVisit),
    hasLength(1),
  );
  expect(
    layerWork.where(
      (event) =>
          event == LayerTableWorkEvent.locationFactEntryVisit ||
          event == LayerTableWorkEvent.fullLocationMapCopy,
    ),
    isEmpty,
  );
  _expectAcceptedDrawWorkComposition(
    candidateEvents,
    deliveryEvents,
    projectionBuilds: root.projectionBuildCount - beforeProjectionBuilds,
    delivery: delivery,
  );

  final explicitWork = observeIdAdmissionWork(() {
    expect(root.generateElementId(), CanvasElementId('e200001'));
  });
  _expectIdAdmissionPhase(
    explicitWork,
    phase: IdAdmissionWorkPhase.generation,
    expected: const {
      IdAdmissionWorkKind.cursorProbe: 1,
      IdAdmissionWorkKind.advance: 1,
      IdAdmissionWorkKind.candidateObservation: 1,
      IdAdmissionWorkKind.reservation: 1,
    },
  );

  final lineWork = observeIdAdmissionWork(() {
    _drawLine(root);
  });
  _expectReadOnlyRouteCandidate(lineWork);
  _expectAcceptedRouteAdmission(lineWork);
  expect(setup.requests[1].entry.layerId, CanvasLayerId('work-layer'));
  expect(setup.requests[1].entry.elementIndex, 195906);
  expect(root.generateElementId(), CanvasElementId('e200003'));

  // Three receivers per public notification prove collection work is owned by
  // delivery phases, not multiplied by callback cardinality.
  var extraRootFrameCallbacks = 0;
  var extraStateCallbacks = 0;
  var extraActionCallbacks = 0;
  void recordRootFrame() => extraRootFrameCallbacks += 1;
  void recordState() => extraStateCallbacks += 1;
  root.surfaceFrameSignal.addListener(recordRootFrame);
  root.surfaceFrameSignal.addListener(recordRootFrame);
  root.state.addListener(recordState);
  root.state.addListener(recordState);
  final extraActionSubscriptions = [
    root.actions.listen((_) => extraActionCallbacks += 1),
    root.actions.listen((_) => extraActionCallbacks += 1),
  ];
  final fourEffectBatch = _knownWorkBatch(effectCount: 4, actionCount: 1);
  final sixEffectBatch = _knownWorkBatch(effectCount: 6, actionCount: 2);
  final fourEffectDeliveryWork = observeDeliveryWork(
    () => root.deliverCommitPlanForTesting(
      fourEffectBatch,
      document: CanvasDocument(),
    ),
  );
  final sixEffectDeliveryWork = observeDeliveryWork(
    () => root.deliverCommitPlanForTesting(
      sixEffectBatch,
      document: CanvasDocument(),
    ),
  );
  _expectSealedDeliveryWork(pencilDeliveryWork, effectCount: 4, actionCount: 1);
  _expectSealedDeliveryWork(
    fourEffectDeliveryWork,
    effectCount: fourEffectBatch.effects.length,
    actionCount: fourEffectBatch.actionIntents.length,
  );
  _expectSealedDeliveryWork(
    sixEffectDeliveryWork,
    effectCount: sixEffectBatch.effects.length,
    actionCount: sixEffectBatch.actionIntents.length,
  );
  expect(
    fourEffectDeliveryWork.effectElements,
    pencilDeliveryWork.effectElements,
  );
  expect(
    fourEffectDeliveryWork.actionElements,
    pencilDeliveryWork.actionElements,
  );
  expect(root.projectionBuildCount - beforeProjectionBuilds, 0);
  expect(extraRootFrameCallbacks, 4);
  expect(extraStateCallbacks, 4);
  expect(extraActionCallbacks, 6);
  expect(releasedResourceIds, [
    {CanvasResourceId('work-resource')},
    {CanvasResourceId('work-resource')},
  ]);
  for (final subscription in extraActionSubscriptions) {
    await subscription.cancel();
  }
  root.surfaceFrameSignal.removeListener(recordRootFrame);
  root.surfaceFrameSignal.removeListener(recordRootFrame);
  root.state.removeListener(recordState);
  root.state.removeListener(recordState);
  await actionSubscription.cancel();
}

// Both batches place repaint last, making the known two RuntimeRoot effect
// traversals linear in the actual sealed batch rather than callback count.
CommitPlan _knownWorkBatch({
  required int effectCount,
  required int actionCount,
}) {
  final nonRepaintEffects = <CommitEffect>[
    SpatialEffect(touchedSet: TouchedSet()),
    ResourceEffect(
      touchedSet: TouchedSet(
        resourceDescriptorChangedIds: [CanvasResourceId('work-resource')],
      ),
    ),
    const ProjectionEffect(),
    const SelectionEffect(),
    const PublicStateEffect(),
  ];
  final actions = <CommitActionIntent>[
    DeleteSelectionActionIntent(removedElementIds: [CanvasElementId('work-a')]),
    DeleteSelectionActionIntent(removedElementIds: [CanvasElementId('work-b')]),
  ];
  return CommitPlan(
    revisionDelta: const StoreRevisionDelta(document: true),
    touchedSet: TouchedSet(),
    effects: [
      ...nonRepaintEffects.take(effectCount - 1),
      const RepaintEffect(mainCanvas: true),
    ],
    actionIntents: actions.take(actionCount).toList(),
  );
}

// The exact cross-owner counts form one falsification proof and are clearer
// together than distributing a single delivery contract through helpers.
// ignore: halstead-volume, number-of-parameters, source-lines-of-code
void _expectAcceptedDrawWorkComposition(
  List<StoreSparseCandidateEvent> candidateEvents,
  List<RuntimeCommonDeliveryEvent> deliveryEvents, {
  required int projectionBuilds,
  required _DrawWorkDeliveryProbe delivery,
}) {
  expect(
    candidateEvents.where(
      (event) => event.kind == StoreSparseCandidateEventKind.open,
    ),
    hasLength(1),
  );
  expect(
    candidateEvents.where(
      (event) =>
          event.kind == StoreSparseCandidateEventKind.aggregatePublication,
    ),
    hasLength(1),
  );
  expect(projectionBuilds, 0);
  expect(delivery.callbackEvents, [
    'root-frame',
    'state',
    'action',
    'observer',
  ]);
  expect(delivery.effectBatches, hasLength(1));
  expect(delivery.effectBatches.single, hasLength(4));
  expect(deliveryEvents.map((event) => event.kind), [
    RuntimeCommonDeliveryEventKind.guardEntered,
    RuntimeCommonDeliveryEventKind.spatialEffectsCompleted,
    RuntimeCommonDeliveryEventKind.resourceEffectsCompleted,
    RuntimeCommonDeliveryEventKind.repaintTargetEffectsCompleted,
    RuntimeCommonDeliveryEventKind.actionFinalizationCompleted,
    RuntimeCommonDeliveryEventKind.actionEmissionCompleted,
    RuntimeCommonDeliveryEventKind.guardReleased,
  ]);
}

// This keeps one literal phase matrix, so a changed owner/read attribution
// cannot hide in fragmented helpers solely to satisfy metrics thresholds.
// ignore: halstead-volume, source-lines-of-code
void _expectSealedDeliveryWork(
  CommitSealedDeliveryWork work, {
  required int effectCount,
  required int actionCount,
}) {
  expect(work.preparations, 1);
  expect(work.effectLengthReads, 1);
  expect(work.effectIterations, 3);
  expect(work.effectElements, effectCount * 3);
  expect(work.actionLengthReads, actionCount + 2);
  expect(work.actionIterations, 0);
  expect(work.actionElements, actionCount);
  _expectSealedDeliveryPhase(work, CommitSealedDeliveryPhase.spatial, (
    effectLengthReads: 0,
    effectIterations: 1,
    effectElements: effectCount,
    actionLengthReads: 0,
    actionIterations: 0,
    actionElements: 0,
  ));
  _expectSealedDeliveryPhase(work, CommitSealedDeliveryPhase.resource, (
    effectLengthReads: 0,
    effectIterations: 1,
    effectElements: effectCount,
    actionLengthReads: 0,
    actionIterations: 0,
    actionElements: 0,
  ));
  _expectSealedDeliveryPhase(work, CommitSealedDeliveryPhase.repaint, (
    effectLengthReads: 0,
    effectIterations: 1,
    effectElements: effectCount,
    actionLengthReads: 0,
    actionIterations: 0,
    actionElements: 0,
  ));
  _expectSealedDeliveryPhase(work, CommitSealedDeliveryPhase.observer, (
    effectLengthReads: 1,
    effectIterations: 0,
    effectElements: 0,
    actionLengthReads: 0,
    actionIterations: 0,
    actionElements: 0,
  ));
  _expectSealedDeliveryPhase(work, CommitSealedDeliveryPhase.action, (
    effectLengthReads: 0,
    effectIterations: 0,
    effectElements: 0,
    actionLengthReads: actionCount + 2,
    actionIterations: 0,
    actionElements: actionCount,
  ));
}

typedef _SealedDeliveryPhaseExpectation = ({
  int effectLengthReads,
  int effectIterations,
  int effectElements,
  int actionLengthReads,
  int actionIterations,
  int actionElements,
});

void _expectSealedDeliveryPhase(
  CommitSealedDeliveryWork work,
  CommitSealedDeliveryPhase phase,
  _SealedDeliveryPhaseExpectation expected,
) {
  final phaseWork = work.phaseWork[phase];
  if (phaseWork == null) {
    fail('missing $phase work attribution');
  }
  expect(phaseWork.effectLengthReads, expected.effectLengthReads);
  expect(phaseWork.effectIterations, expected.effectIterations);
  expect(phaseWork.effectElements, expected.effectElements);
  expect(phaseWork.actionLengthReads, expected.actionLengthReads);
  expect(phaseWork.actionIterations, expected.actionIterations);
  expect(phaseWork.actionElements, expected.actionElements);
}

void _expectReadOnlyRouteCandidate(IdAdmissionWorkRecorder work) {
  _expectIdAdmissionPhase(
    work,
    phase: IdAdmissionWorkPhase.generation,
    expected: const {IdAdmissionWorkKind.candidateObservation: 1},
  );
}

void _expectAcceptedRouteAdmission(IdAdmissionWorkRecorder work) {
  _expectIdAdmissionPhase(
    work,
    phase: IdAdmissionWorkPhase.acceptedAdmission,
    expected: const {
      IdAdmissionWorkKind.sparseLedgerVisit: 1,
      IdAdmissionWorkKind.inputVisit: 1,
      IdAdmissionWorkKind.cursorProbe: 2,
      IdAdmissionWorkKind.collision: 1,
      IdAdmissionWorkKind.advance: 1,
    },
  );
}

CanvasDocument _supportedPrefixDocument() {
  const unrelatedLayerCount = 4095;
  return CanvasDocument(
    layers: [
      for (var index = 0; index < unrelatedLayerCount; index += 1)
        CanvasLayer(
          id: CanvasLayerId('unrelated-layer-$index'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('e$index'),
              size: const Size(1, 1),
            ),
          ],
        ),
      CanvasLayer(
        id: CanvasLayerId('work-layer'),
        elements: List<CanvasElement>.generate(
          200000 - unrelatedLayerCount,
          (index) => CanvasRectElement(
            id: CanvasElementId('e${index + unrelatedLayerCount}'),
            size: const Size(1, 1),
          ),
          growable: false,
        ),
      ),
    ],
  );
}

void _expectIdAdmissionPhase(
  IdAdmissionWorkRecorder work, {
  required IdAdmissionWorkPhase phase,
  required Map<IdAdmissionWorkKind, int> expected,
}) {
  for (final kind in IdAdmissionWorkKind.values) {
    expect(
      work.count(prefix: 'e', phase: phase, kind: kind),
      expected[kind] ?? 0,
    );
  }
}

Future<void> _verifyProgrammaticAddElementActionSilence() async {
  final scenario = _scenario();

  scenario.root.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(id: CanvasElementId('rect-a'), size: const Size(1, 1)),
    );
  });
  await Future<void>.delayed(Duration.zero);

  expect(scenario.actions, isEmpty);
  expect(scenario.root.readDocument().layers.single.elements, hasLength(1));
}

_DrawScenario _scenario({CanvasDocument? initialDocument}) {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    initialDocument ?? CanvasDocument(),
    commitEffectObserver: effectBatches.add,
  );
  final actions = <CanvasActionCommitted>[];
  final actionStates = <CanvasRuntimeState>[];
  final subscription = root.actions.listen((action) {
    actions.add(action);
    actionStates.add(root.state.value);
  });
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return (
    root: root,
    actions: actions,
    actionStates: actionStates,
    effectBatches: effectBatches,
  );
}

typedef _DrawScenario = ({
  RuntimeRoot root,
  List<CanvasActionCommitted> actions,
  List<CanvasRuntimeState> actionStates,
  List<List<CommitDeliveryEffect>> effectBatches,
});

typedef _RouteWorkSetup = ({
  RuntimeRoot root,
  IdAdmissionWorkRecorder resetWork,
  _DrawWorkDeliveryProbe delivery,
  List<CanvasDrawCommitRequest> requests,
});

final class _DrawWorkDeliveryProbe {
  final List<String> callbackEvents = [];
  final List<List<CommitDeliveryEffect>> effectBatches = [];
  var _isCommonDeliveryActive = false;

  void observeCommonDeliveryEvent(RuntimeCommonDeliveryEvent event) {
    switch (event.kind) {
      case RuntimeCommonDeliveryEventKind.guardEntered:
        _isCommonDeliveryActive = true;
      case RuntimeCommonDeliveryEventKind.guardReleased:
        _isCommonDeliveryActive = false;
      default:
        break;
    }
  }

  void observeRootFrame() {
    if (_isCommonDeliveryActive) {
      callbackEvents.add('root-frame');
    }
  }

  void observeState() {
    if (_isCommonDeliveryActive) {
      callbackEvents.add('state');
    }
  }

  void observeAction(CanvasActionCommitted _) {
    if (_isCommonDeliveryActive) {
      callbackEvents.add('action');
    }
  }

  void observeEffects(List<CommitDeliveryEffect> effects) {
    if (_isCommonDeliveryActive) {
      callbackEvents.add('observer');
      effectBatches.add(effects);
    }
  }
}

final class _DrawLease implements CanvasCommitLease {
  _DrawLease({this.onCommitted});

  void Function()? onCommitted;
  void Function()? onAborted;
  int committedCalls = 0;
  int abortedCalls = 0;

  @override
  void aborted() {
    abortedCalls += 1;
    onAborted?.call();
  }

  @override
  void committed() {
    committedCalls += 1;
    onCommitted?.call();
  }
}

CanvasPointerSample _pointer(
  CanvasPointerLifecyclePhase phase,
  Offset position, [
  int? timestampMs,
]) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}
