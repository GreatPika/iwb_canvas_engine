import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _registerLoadSuccessCleanupTests();
  _registerLoadFailureCleanupTests();
  _registerDisposeCleanupTests();
}

void _registerLoadSuccessCleanupTests() {
  test(
    'prepared load success clears selected move interaction before install',
    () {
      expect(
        () => _verifyLoadSuccessCleanup(
          const CanvasSelectedMovePreview(delta: Offset(4, 5)),
        ),
        returnsNormally,
      );
    },
  );

  test('prepared load success clears marquee interaction before install', () {
    expect(
      () => _verifyLoadSuccessCleanup(
        const CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4)),
      ),
      returnsNormally,
    );
  });

  test('prepared load success clears eraser interaction before install', () {
    expect(_verifyLoadSuccessCleansEraserInteraction, returnsNormally);
  });

  test('prepared load success clears pending context tap before install', () {
    expect(_verifyLoadSuccessCleansPendingContextTap, returnsNormally);
  });

  test('successful load clears live context request facts', () {
    return expectLater(_verifyLoadSuccessClearsLiveRequestFacts(), completes);
  });
}

void _registerLoadFailureCleanupTests() {
  test('load failure preserves active interaction state', () {
    expect(_verifyLoadFailurePreservesInteraction, returnsNormally);
  });

  test('load failure preserves pending context tap', () {
    expect(_verifyLoadFailurePreservesPendingContextTap, returnsNormally);
  });
}

void _registerDisposeCleanupTests() {
  test('dispose cleanup publishes before streams close only when needed', () {
    expect(_verifyDisposeCleanupPublication, returnsNormally);
  });

  test('dispose restores provisional unselected-drag selection', () {
    expect(_verifyDisposeRestoresProvisionalSelection, returnsNormally);
  });

  test('dispose clears live context request facts', () {
    return expectLater(_verifyDisposeClearsLiveRequestFacts(), completes);
  });
}

void _verifyLoadSuccessCleanup(CanvasPreviewState preview) {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final actionEvents = <CanvasActionCommitted>[];
  final root = _runtimeRoot(effectBatches.add);
  root.actions.listen(actionEvents.add);
  _startPointerSession(root);
  root.replaceInteractionPreview(preview);
  final before = root.state.value;
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  root.edits.loadDocument(_replacementDocument());

  expect(snapshots, hasLength(1));
  expect(root.interactionEngine.activeSession, isNull);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(actionEvents, isEmpty);
  expect(effectBatches, hasLength(1));
  _expectLoadCleanupRevisions(before, snapshots.single);
}

void _verifyLoadFailurePreservesInteraction() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final actionEvents = <CanvasActionCommitted>[];
  final root = _runtimeRoot(effectBatches.add);
  root.actions.listen(actionEvents.add);
  _startPointerSession(root);
  root.replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(4, 5)),
  );
  final before = root.state.value;
  final activeSession = root.interactionEngine.activeSession;
  final preview = root.preview;
  var publications = 0;
  root.state.addListener(() {
    publications += 1;
  });

  expect(
    () => root.edits.loadDocument(_invalidReplacementDocument()),
    throwsA(isA<CanvasDataException>()),
  );

  expect(publications, 0);
  expect(root.state.value, before);
  _expectInteractionPreserved(
    root: root,
    activeSession: activeSession,
    preview: preview,
    sideEffects: (effectBatches: effectBatches, actionEvents: actionEvents),
  );
}

void _verifyLoadSuccessCleansEraserInteraction() {
  final actionEvents = <CanvasActionCommitted>[];
  final root = _runtimeRoot(_ignoreCommitEffects);
  root.actions.listen(actionEvents.add);
  _startEraserSession(root);
  final before = root.state.value;
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  root.edits.loadDocument(_replacementDocument());

  expect(snapshots, hasLength(1));
  expect(root.interactionEngine.activeSession, isNull);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(actionEvents, isEmpty);
  _expectLoadCleanupRevisions(before, snapshots.single);
}

void _verifyLoadSuccessCleansPendingContextTap() {
  final actionEvents = <CanvasActionCommitted>[];
  final contextRequests = <CanvasContextActionRequested>[];
  final root = _runtimeRoot(_ignoreCommitEffects);
  root.actions.listen(actionEvents.add);
  root.contextActionRequests.listen(contextRequests.add);
  _startPendingContextTap(root);

  root.edits.loadDocument(_replacementDocument());

  expect(root.interactionEngine.pendingContextTap, isNull);
  expect(root.readDocument().layers.single.id, CanvasLayerId('new-layer'));
  expect(actionEvents, isEmpty);
  expect(contextRequests, isEmpty);
}

void _verifyLoadFailurePreservesPendingContextTap() {
  final actionEvents = <CanvasActionCommitted>[];
  final contextRequests = <CanvasContextActionRequested>[];
  final root = _runtimeRoot(_ignoreCommitEffects);
  root.actions.listen(actionEvents.add);
  root.contextActionRequests.listen(contextRequests.add);
  _startPendingContextTap(root);
  final before = root.state.value;
  final pendingTap = root.interactionEngine.pendingContextTap;
  var publications = 0;
  root.state.addListener(() {
    publications += 1;
  });

  expect(
    () => root.edits.loadDocument(_invalidReplacementDocument()),
    throwsA(isA<CanvasDataException>()),
  );

  expect(publications, 0);
  expect(root.state.value, before);
  expect(root.interactionEngine.pendingContextTap, same(pendingTap));
  expect(actionEvents, isEmpty);
  expect(contextRequests, isEmpty);
}

Future<void> _verifyLoadSuccessClearsLiveRequestFacts() async {
  final root = _runtimeRoot(_ignoreCommitEffects);
  try {
    final request = await _issueContextRequest(root);
    expect(
      root.interactionEngine.requestFactsFor(request.requestId),
      isNotNull,
    );

    root.edits.loadDocument(_replacementDocument());

    expect(root.interactionEngine.requestFactsFor(request.requestId), isNull);
    expect(root.readDocument().layers.single.id, CanvasLayerId('new-layer'));
  } finally {
    root.dispose();
  }
}

Future<void> _verifyDisposeClearsLiveRequestFacts() async {
  final root = _runtimeRoot(_ignoreCommitEffects);
  final request = await _issueContextRequest(root);
  expect(root.interactionEngine.requestFactsFor(request.requestId), isNotNull);

  root.dispose();

  expect(root.interactionEngine.requestFactsFor(request.requestId), isNull);
}

Future<CanvasContextActionRequested> _issueContextRequest(RuntimeRoot root) {
  final request = root.contextActionRequests.first;
  root.handleDoubleTap(position: Offset.zero, timestampMs: 1);

  return request;
}

void _expectInteractionPreserved({
  required RuntimeRoot root,
  required Object? activeSession,
  required CanvasPreviewState preview,
  required ({
    List<List<CommitDeliveryEffect>> effectBatches,
    List<CanvasActionCommitted> actionEvents,
  })
  sideEffects,
}) {
  expect(root.interactionEngine.activeSession, same(activeSession));
  expect(root.preview, same(preview));
  expect(sideEffects.effectBatches, isEmpty);
  expect(sideEffects.actionEvents, isEmpty);
}

void _verifyDisposeCleanupPublication() {
  _expectDisposeWithoutInteractionSilent();
  _expectDisposeWithInteractionPublishesCleanup();
}

void _expectDisposeWithoutInteractionSilent() {
  final root = _runtimeRoot(_ignoreCommitEffects);
  var publications = 0;
  root.state.addListener(() {
    publications += 1;
  });
  final before = root.state.value;

  root.dispose();

  expect(publications, 0);
  expect(root.state.value, before);
}

void _expectDisposeWithInteractionPublishesCleanup() {
  final actionEvents = <CanvasActionCommitted>[];
  final root = _runtimeRoot(_ignoreCommitEffects);
  root.actions.listen(actionEvents.add);
  _startPointerSession(root);
  root.replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(4, 5)),
  );
  final before = root.state.value;
  final listenerProbe = _recordDisposeCleanupListener(root);

  root.dispose();

  _expectDisposeListenerProbe(listenerProbe);
  _expectInteractionCleared(root);
  expect(actionEvents, isEmpty);
  _expectDisposeCleanupRevisions(before, root.state.value);
}

void _verifyDisposeRestoresProvisionalSelection() {
  final actionEvents = <CanvasActionCommitted>[];
  final root = _unselectedMoveRuntimeRoot(_ignoreCommitEffects);
  root.actions.listen(actionEvents.add);
  _startProvisionalUnselectedMove(root);
  final listenerProbe = _recordSelectionSnapshots(root);

  root.dispose();

  _expectDisposeRestoredSelection(root, listenerProbe, actionEvents);
}

void _startProvisionalUnselectedMove(RuntimeRoot root) {
  root.selection.setSelection([CanvasElementId('previous')]);
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(5, 0)),
  );
  expect(root.selection.selectedElementIds, {CanvasElementId('dragged')});
}

({List<CanvasRuntimeState> snapshots, List<Set<CanvasElementId>> selections})
_recordSelectionSnapshots(RuntimeRoot root) {
  final snapshots = <CanvasRuntimeState>[];
  final selections = <Set<CanvasElementId>>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
    selections.add(root.selectedElementIds);
  });

  return (snapshots: snapshots, selections: selections);
}

void _expectDisposeRestoredSelection(
  RuntimeRoot root,
  ({List<CanvasRuntimeState> snapshots, List<Set<CanvasElementId>> selections})
  listenerProbe,
  List<CanvasActionCommitted> actionEvents,
) {
  expect(root.selection.selectedElementIds, {CanvasElementId('previous')});
  expect(listenerProbe.snapshots, hasLength(1));
  expect(listenerProbe.selections.single, {CanvasElementId('previous')});
  expect(actionEvents, isEmpty);
}

({List<CanvasRuntimeState> snapshots, List<Object> listenerErrors})
_recordDisposeCleanupListener(RuntimeRoot root) {
  final snapshots = <CanvasRuntimeState>[];
  final listenerErrors = <Object>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
    try {
      root.selection.clearSelection();
    } on Object catch (error) {
      listenerErrors.add(error);
    }
  });

  return (snapshots: snapshots, listenerErrors: listenerErrors);
}

void _expectDisposeListenerProbe(
  ({List<CanvasRuntimeState> snapshots, List<Object> listenerErrors}) probe,
) {
  expect(probe.snapshots, hasLength(1));
  expect(
    probe.listenerErrors,
    contains(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('disposed'),
      ),
    ),
  );
}

void _expectInteractionCleared(RuntimeRoot root) {
  expect(root.interactionEngine.activeSession, isNull);
  expect(root.preview, isA<CanvasNoPreview>());
}

void _expectLoadCleanupRevisions(
  CanvasRuntimeState before,
  CanvasRuntimeState after,
) {
  expect(after.revisions.document, before.revisions.document + 1);
  expect(after.revisions.selection, before.revisions.selection + 1);
  expect(after.revisions.preview, before.revisions.preview + 1);
  expect(after.revisions.interaction, before.revisions.interaction);
  expect(after.revisions.epoch, before.revisions.epoch + 1);
}

void _expectDisposeCleanupRevisions(
  CanvasRuntimeState before,
  CanvasRuntimeState after,
) {
  expect(after.revisions.document, before.revisions.document);
  expect(after.revisions.selection, before.revisions.selection);
  expect(after.revisions.resourceVisual, before.revisions.resourceVisual);
  expect(after.revisions.preview, before.revisions.preview + 1);
  expect(after.revisions.interaction, before.revisions.interaction);
  expect(after.revisions.epoch, before.revisions.epoch);
  expect(after.summary, before.summary);
}

RuntimeRoot _runtimeRoot(CommitEffectObserver observer) {
  return RuntimeRoot(
    initialDocument: _initialDocument(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: observer,
  );
}

RuntimeRoot _unselectedMoveRuntimeRoot(CommitEffectObserver observer) {
  return RuntimeRoot(
    initialDocument: _unselectedMoveDocument(),
    config: CanvasRuntimeConfig(
      pointerPolicy: CanvasPointerPolicy(tapSlop: 16, dragStartSlop: 4),
    ),
    commitEffectObserver: observer,
  );
}

int _ignoreCommitEffects(List<CommitDeliveryEffect> effects) {
  return Object.hash(effects, null);
}

void _startPointerSession(RuntimeRoot root) {
  root.selection.setSelection([CanvasElementId('old')]);
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

void _startEraserSession(RuntimeRoot root) {
  root
    ..setInteractionMode(CanvasInteractionMode.draw)
    ..setDrawStyle(
      CanvasDrawStyle(tool: CanvasDrawTool.eraser, eraserThickness: 6),
    )
    ..handlePointer(
      CanvasPointerSample(
        pointerId: 1,
        position: Offset.zero,
        phase: CanvasPointerLifecyclePhase.down,
        kind: PointerDeviceKind.touch,
      ),
    )
    ..handlePointer(
      CanvasPointerSample(
        pointerId: 1,
        position: const Offset(1, 0),
        phase: CanvasPointerLifecyclePhase.move,
        kind: PointerDeviceKind.touch,
      ),
    );

  expect(root.interactionEngine.activeSession, isNotNull);
  expect(root.preview, isA<CanvasEraserPreview>());
}

void _startPendingContextTap(RuntimeRoot root) {
  const position = Offset(20, 20);
  root.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: position,
      phase: CanvasPointerLifecyclePhase.down,
      kind: PointerDeviceKind.touch,
    ),
  );
  root.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: position,
      phase: CanvasPointerLifecyclePhase.up,
      kind: PointerDeviceKind.touch,
    ),
  );

  expect(root.interactionEngine.pendingContextTap, isNotNull);
  expect(root.interactionEngine.activeSession, isNull);
}

CanvasPointerSample _pointer(
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

CanvasDocument _initialDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('old-layer'),
        elements: [
          CanvasRectElement(id: CanvasElementId('old'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}

CanvasDocument _unselectedMoveDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('old-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('dragged'),
            size: const Size(10, 10),
          ),
          CanvasRectElement(
            id: CanvasElementId('previous'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('new-layer'),
        elements: [
          CanvasRectElement(id: CanvasElementId('new'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}

CanvasDocument _invalidReplacementDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('bad-layer'),
        elements: [
          CanvasRectElement(id: CanvasElementId('dup'), size: const Size(1, 1)),
          CanvasRectElement(id: CanvasElementId('dup'), size: const Size(2, 2)),
        ],
      ),
    ],
  );
}
