import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/load_interaction_boundary.dart';
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
}

Future<void> _expectFailedLoadDoesNotInterrupt() async {
  final boundary = _RecordingLoadBoundary();
  final root = _runtimeRoot(boundary);
  final actionEvents = <CanvasActionCommitted>[];
  final beforeState = root.state.value;
  root.actions.listen(actionEvents.add);

  expect(
    () => root.edits.loadDocument(_invalidReplacementDocument()),
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

final class _SuccessfulLoadOrderingScenario {
  final _RecordingLoadBoundary boundary = _RecordingLoadBoundary();
  final List<String> events = [];
  late final RuntimeRoot root;

  void run() {
    boundary.onPrepareCleanup = () =>
        _recordSuccessfulPrepareCleanup(events, root);
    root = _runtimeRoot(
      boundary,
      observeEffects: (effects) =>
          _recordSuccessfulObserver(events, root, effects),
    );
    _prepareActiveInteraction(root);
    root.state.addListener(() => _recordSuccessfulState(events, root));

    root.edits.loadDocument(_replacementDocument());

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
  return RuntimeRoot.test(
    initialDocument: _initialDocument(),
    config: const CanvasRuntimeConfig(),
    loadInteractionBoundary: boundary,
    commitEffectObserver: observeEffects,
  );
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
  _expectGuarded(() => root.edits.loadDocument(CanvasDocument()));
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
    () => root.edits.loadDocument(_replacementDocument()),
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
