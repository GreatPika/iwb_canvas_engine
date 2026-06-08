import 'dart:ui';
import "../../support/runtime_root_with_document.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/load_interaction_boundary.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('failed load prepares before interaction interruption', () {
    return expectLater(_expectFailedLoadDoesNotInterrupt(), completes);
  });

  test('successful load interrupts before install and publishes once', () {
    expect(_expectSuccessOrderingAndGuards, returnsNormally);
  });

  test('prepared cleanup failure stays before install and publication', () {
    return expectLater(
      _expectPreparedCleanupFailureHasNoSideEffects(),
      completes,
    );
  });

  test('prepared cleanup rejects reentrant public mutations', () {
    expect(_expectPreparedCleanupReentrancyGuard, returnsNormally);
  });

  test('text edit cleanup listener rejects reentrant public mutations', () {
    return expectLater(_expectTextEditCleanupReentrancyGuard(), completes);
  });

  test('action stream listener delivery rejects reentrant loads', () {
    expect(_expectActionStreamDeliveryGuards, returnsNormally);
  });
}

Future<void> _expectFailedLoadDoesNotInterrupt() async {
  final boundary = _RecordingLoadBoundary();
  final root = _runtimeRoot(boundary);
  final actionEvents = <CanvasActionCommitted>[];
  final beforeState = root.state.value;
  root.actions.listen(actionEvents.add);

  expect(
    () => root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_invalidReplacementDocument()),
    ),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.duplicateElementId,
      ),
    ),
  );
  await _drainActionStream();

  expect(boundary.events, isEmpty);
  expect(root.readDocument().layers.single.elements.single.id.value, 'old');
  expect(root.state.value, beforeState);
  expect(actionEvents, isEmpty);
}

void _expectSuccessOrderingAndGuards() {
  _SuccessfulLoadOrderingScenario().run();
}

Future<void> _expectPreparedCleanupFailureHasNoSideEffects() async {
  final boundary = _RecordingLoadBoundary();
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final actionEvents = <CanvasActionCommitted>[];
  final events = <String>[];
  final root = _runtimeRoot(
    boundary,
    observeEffects: (effects) =>
        _recordLoadFailureObserver(events, effectBatches, effects),
  );
  _prepareExistingRuntimeFacts(root);
  _prepareActiveInteraction(root);
  final before = _RuntimeFactsSnapshot.capture(root);
  _recordLoadFailurePublicSignals(root, events, actionEvents);
  boundary.onPrepareCleanup = () => _throwFromPreparedCleanup(events);

  _expectPreparedCleanupLoadThrows(root);
  await _drainActionStream();

  expect(events, ['prepared-cleanup']);
  expect(boundary.events, ['prepared-cleanup']);
  before.expectStillCurrent(root);
  expect(effectBatches, isEmpty);
  expect(actionEvents, isEmpty);
}

void _expectPreparedCleanupReentrancyGuard() {
  final boundary = _RecordingLoadBoundary();
  final root = _runtimeRoot(boundary);
  final guardEvents = <String>[];
  boundary.onPrepareCleanup = () {
    guardEvents.add('cleanup');
    _expectDocumentLoadGuarded(() => root.edits.edit(_ignoreEditMutation));
    _expectDocumentLoadGuarded(
      () => root.edits.loadDocumentFromJson(
        encodeCanvasDocumentToJson(CanvasDocument()),
      ),
    );
    _expectDocumentLoadGuarded(root.dispose);
  };

  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_replacementDocument()),
  );

  expect(guardEvents, ['cleanup']);
  expect(root.readDocument().backgroundElements.single.id.value, 'new');
  expect(root.state.value.revisions.document, 1);
}

// This scenario intentionally keeps request creation, session start, listener
// cleanup, and reentrant guard assertions together to prove one temporal window.
// ignore: halstead-volume
Future<void> _expectTextEditCleanupReentrancyGuard() async {
  final root = runtimeRootWithDocument(
    _textDocument(),
    config: const CanvasRuntimeConfig(),
  );
  final requests = <CanvasContextActionRequested>[];
  final subscription = root.contextActionRequests.listen(requests.add);
  try {
    root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
    await _drainActionStream();
    final request = requests.single;
    final session = root.textEditing.startFromContextAction(request);
    expect(session, isNotNull);
    var guardAttempts = 0;
    root.textEditing.activeSession.addListener(() {
      if (root.textEditing.activeSession.value != null) {
        return;
      }
      guardAttempts += 1;
      _expectDocumentLoadGuarded(() => root.edits.edit(_ignoreEditMutation));
      _expectDocumentLoadGuarded(
        () => root.edits.loadDocumentFromJson(
          encodeCanvasDocumentToJson(CanvasDocument()),
        ),
      );
    });

    root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_replacementDocument()),
    );

    expect(guardAttempts, 1);
    expect(root.readDocument().backgroundElements.single.id.value, 'new');
  } finally {
    await subscription.cancel();
    root.dispose();
  }
}

void _expectActionStreamDeliveryGuards() {
  final records = _ActionStreamDeliveryRecords();
  final root = _runtimeRoot(
    _RecordingLoadBoundary(),
    observeEffects: records.effectBatches.add,
  );
  root.selection.setSelection([CanvasElementId('old')]);
  root.cameraPort().setOffset(const Offset(4, 5));
  root.state.addListener(() => records.stateSnapshots.add(root.state.value));
  root.actions.listen(
    (action) => _recordGuardedActionDelivery(root, records, action),
  );

  _deliverActionCommitForGuardTest(root);
  _expectActionStreamGuardOutcome(root, records);
}

void _recordGuardedActionDelivery(
  RuntimeRoot root,
  _ActionStreamDeliveryRecords records,
  CanvasActionCommitted action,
) {
  records.actionDeliveries += 1;
  expect(action.type, CanvasActionType.deleteElements);
  final duringDelivery = _captureActionStreamDelivery(root, records);

  _expectDeliveryGuards(root);
  duringDelivery.expectStillCurrent(
    root,
    actionDeliveries: records.actionDeliveries,
    statePublicationCount: records.stateSnapshots.length,
    observerCount: records.effectBatches.length,
  );
}

void _expectActionStreamGuardOutcome(
  RuntimeRoot root,
  _ActionStreamDeliveryRecords records,
) {
  expect(records.actionDeliveries, 1);
  expect(records.stateSnapshots, hasLength(1));
  expect(records.effectBatches, hasLength(1));
  _captureActionStreamDelivery(root, records).expectStillCurrent(
    root,
    actionDeliveries: 1,
    statePublicationCount: 1,
    observerCount: 1,
  );
}

_ActionStreamDeliverySnapshot _captureActionStreamDelivery(
  RuntimeRoot root,
  _ActionStreamDeliveryRecords records,
) {
  return _ActionStreamDeliverySnapshot.capture(
    root,
    actionDeliveries: records.actionDeliveries,
    statePublicationCount: records.stateSnapshots.length,
    observerCount: records.effectBatches.length,
  );
}

final class _ActionStreamDeliveryRecords {
  final List<CanvasRuntimeState> stateSnapshots = [];
  final List<List<CommitDeliveryEffect>> effectBatches = [];
  int actionDeliveries = 0;
}

final class _ActionStreamDeliverySnapshot {
  const _ActionStreamDeliverySnapshot({
    required this.document,
    required this.selection,
    required this.cameraOffset,
    required this.state,
    required this.actionDeliveries,
    required this.statePublicationCount,
    required this.observerCount,
  });

  factory _ActionStreamDeliverySnapshot.capture(
    RuntimeRoot root, {
    required int actionDeliveries,
    required int statePublicationCount,
    required int observerCount,
  }) {
    return _ActionStreamDeliverySnapshot(
      document: root.readDocument(),
      selection: root.selectedElementIds,
      cameraOffset: root.cameraPort().offset,
      state: root.state.value,
      actionDeliveries: actionDeliveries,
      statePublicationCount: statePublicationCount,
      observerCount: observerCount,
    );
  }

  final CanvasDocument document;
  final Set<CanvasElementId> selection;
  final Offset cameraOffset;
  final CanvasRuntimeState state;
  final int actionDeliveries;
  final int statePublicationCount;
  final int observerCount;

  void expectStillCurrent(
    RuntimeRoot root, {
    required int actionDeliveries,
    required int statePublicationCount,
    required int observerCount,
  }) {
    expect(root.readDocument(), same(document));
    expect(root.selectedElementIds, selection);
    expect(root.cameraPort().offset, cameraOffset);
    expect(root.state.value, state);
    expect(actionDeliveries, this.actionDeliveries);
    expect(statePublicationCount, this.statePublicationCount);
    expect(observerCount, this.observerCount);
  }
}

void _deliverActionCommitForGuardTest(RuntimeRoot root) {
  root.deliverCommitPlanForTesting(
    CommitPlan.replaceSelection(
      elementIds: const [],
      actionIntents: [
        DeleteSelectionActionIntent(
          removedElementIds: [CanvasElementId('old')],
        ),
      ],
    ),
    document: root.readDocument(),
  );
}

final class _SuccessfulLoadOrderingScenario {
  final _RecordingLoadBoundary boundary = _RecordingLoadBoundary();
  final List<String> events = [];
  late final RuntimeRoot root;

  void run() {
    root = _runtimeRoot(
      boundary,
      observeEffects: (effects) =>
          _recordSuccessfulObserver(events, root, effects),
    );
    boundary.onPrepareCleanup = () =>
        _recordSuccessfulPrepareCleanup(events, root);
    _prepareActiveInteraction(root);
    root.state.addListener(() => _recordSuccessfulState(events, root));

    root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_replacementDocument()),
    );

    expect(events, ['prepared-cleanup', 'state', 'observer']);
    expect(boundary.events, ['prepared-cleanup']);
    _expectNoInteractionEventBetweenCleanupAndPublication(events);
  }
}

void _recordSuccessfulPrepareCleanup(List<String> events, RuntimeRoot root) {
  events.add('prepared-cleanup');
  expect(root.readDocument().layers.single.elements.single.id.value, 'old');
  expect(root.state.value.revisions.document, 0);
}

void _recordSuccessfulState(List<String> events, RuntimeRoot root) {
  events.add('state');
  _expectPublishedLoadState(root);
  _expectDeliveryGuards(root);
}

void _recordSuccessfulObserver(
  List<String> events,
  RuntimeRoot root,
  List<CommitDeliveryEffect> effects,
) {
  events.add('observer');
  expect(effects.whereType<PublicStateDeliveryEffect>(), hasLength(1));
  _expectPublishedLoadState(root);
  _expectDeliveryGuards(root);
}

void _expectNoInteractionEventBetweenCleanupAndPublication(
  List<String> events,
) {
  final publicationIndex = events.indexOf('state');
  final interactionEventsBeforePublication = events
      .take(publicationIndex)
      .where(_isInteractionBoundaryEvent);

  expect(interactionEventsBeforePublication, ['prepared-cleanup']);
}

bool _isInteractionBoundaryEvent(String event) {
  return event == 'prepared-cleanup';
}

RuntimeRoot _runtimeRoot(
  _RecordingLoadBoundary boundary, {
  void Function(List<CommitDeliveryEffect> effects)? observeEffects,
}) {
  final root = runtimeRootWithDocument(
    _initialDocument(),
    config: const CanvasRuntimeConfig(),
    loadInteractionBoundary: boundary,
    commitEffectObserver: observeEffects,
  );
  boundary.events.clear();

  return root;
}

void _expectPublishedLoadState(RuntimeRoot root) {
  expect(root.readDocument().backgroundElements.single.id.value, 'new');
  expect(root.state.value.summary.elementCount, 1);
  expect(root.state.value.revisions.document, 1);
  expect(root.state.value.revisions.epoch, 1);
  _expectInteractionAlreadyCleaned(root);
}

void _prepareActiveInteraction(RuntimeRoot root) {
  root.replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(2, 3)),
  );
  root.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: Offset.zero,
      phase: CanvasPointerLifecyclePhase.down,
      kind: PointerDeviceKind.touch,
    ),
  );
  expect(root.interactionEngine.activeSession, isNotNull);
}

void _expectInteractionAlreadyCleaned(RuntimeRoot root) {
  expect(root.preview, isA<CanvasNoPreview>());
}

void _expectDeliveryGuards(RuntimeRoot root) {
  _expectGuarded(() => root.edits.edit(_ignoreEditMutation));
  _expectGuarded(
    () => root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(CanvasDocument()),
    ),
  );
  _expectGuarded(() => root.selection.setSelection([CanvasElementId('new')]));
  _expectGuarded(() => root.cameraPort().setOffset(const Offset(1, 1)));
  _expectGuarded(root.generateElementId);
  _expectGuarded(root.generateLayerId);
  _expectGuarded(root.generateResourceId);
  _expectGuarded(root.dispose);
}

int _ignoreEditMutation(Object edit) => Object.hash(edit, null);

void _expectGuarded(void Function() action) {
  expect(
    action,
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('post-commit effect delivery'),
      ),
    ),
  );
}

void _expectDocumentLoadGuarded(void Function() action) {
  expect(
    action,
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('document load'),
      ),
    ),
  );
}

void _prepareExistingRuntimeFacts(RuntimeRoot root) {
  root.selection.setSelection([CanvasElementId('old')]);
  root.cameraPort().setOffset(const Offset(4, 5));
}

void _recordLoadFailurePublicSignals(
  RuntimeRoot root,
  List<String> events,
  List<CanvasActionCommitted> actionEvents,
) {
  root.state.addListener(() {
    events.add('state');
  });
  root.actions.listen((action) {
    events.add('action');
    actionEvents.add(action);
  });
}

void _recordLoadFailureObserver(
  List<String> events,
  List<List<CommitDeliveryEffect>> effectBatches,
  List<CommitDeliveryEffect> effects,
) {
  events.add('observer');
  effectBatches.add(effects);
}

Never _throwFromPreparedCleanup(List<String> events) {
  events.add('prepared-cleanup');
  throw StateError('prepared cleanup failed');
}

void _expectPreparedCleanupLoadThrows(RuntimeRoot root) {
  expect(
    () => root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_replacementDocument()),
    ),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        'prepared cleanup failed',
      ),
    ),
  );
}

Future<void> _drainActionStream() {
  return Future<void>.delayed(Duration.zero);
}

final class _RuntimeFactsSnapshot {
  const _RuntimeFactsSnapshot({
    required this.state,
    required this.document,
    required this.selection,
    required this.cameraOffset,
    required this.preview,
    required this.activeSession,
  });

  factory _RuntimeFactsSnapshot.capture(RuntimeRoot root) {
    return _RuntimeFactsSnapshot(
      state: root.state.value,
      document: root.readDocument(),
      selection: root.selectedElementIds,
      cameraOffset: root.cameraPort().offset,
      preview: root.preview,
      activeSession: root.interactionEngine.activeSession,
    );
  }

  final CanvasRuntimeState state;
  final CanvasDocument document;
  final Set<CanvasElementId> selection;
  final Offset cameraOffset;
  final CanvasPreviewState preview;
  final Object? activeSession;

  void expectStillCurrent(RuntimeRoot root) {
    expect(root.state.value, state);
    expect(root.readDocument(), same(document));
    expect(root.readDocument().layers.single.elements.single.id.value, 'old');
    expect(root.selectedElementIds, selection);
    expect(root.cameraPort().offset, cameraOffset);
    expect(root.preview, same(preview));
    expect(root.interactionEngine.activeSession, same(activeSession));
  }
}

CanvasDocument _initialDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasRectElement(id: CanvasElementId('old'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('new'), size: const Size(1, 1)),
    ],
  );
}

CanvasDocument _textDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('text-layer'),
        elements: [
          CanvasTextElement(
            id: CanvasElementId('text-a'),
            text: 'hello',
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _invalidReplacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('duplicate'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('duplicate'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

final class _RecordingLoadBoundary implements LoadInteractionBoundary {
  final List<String> events = [];
  void Function()? onPrepareCleanup;

  @override
  LoadInteractionCleanupOutcome prepareLoadCleanup() {
    events.add('prepared-cleanup');
    onPrepareCleanup?.call();

    return LoadInteractionCleanupOutcome.noChange;
  }
}
