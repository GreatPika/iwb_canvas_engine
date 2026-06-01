import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
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

  test('load failure preserves active interaction state', () {
    expect(_verifyLoadFailurePreservesInteraction, returnsNormally);
  });

  test('dispose cleanup publishes before streams close only when needed', () {
    expect(_verifyDisposeCleanupPublication, returnsNormally);
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
  final root = _runtimeRoot((_) {});
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
  final root = _runtimeRoot((_) {});
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
  expect(after.revisions.interaction, before.revisions.interaction + 1);
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
  expect(after.revisions.interaction, before.revisions.interaction + 1);
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
