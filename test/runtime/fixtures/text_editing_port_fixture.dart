import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/frame/frame_text_layout_measurer.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
// This one cohesive runtime fixture observes both the Store pair seam and its
// existing committed-document preparation trace; a second fixture would hide
// their required causal order.
// ignore_for_file: number-of-imports
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  _testCandidateLookup();
  _testNonTextCandidateLookup();
  _testReadOnlyAdmission();
  _testSingleActiveAdmission();
  _testLiveUpdateRemeasuresGeometry();
  _testLiveGeometryPreservesTextAlignmentAnchor();
  _testRuntimeUsesMeasuredLayoutBoundary();
  _testActiveSessionPublishesLiveUpdates();
  _testChangedTextListenerRunsAfterOuterDelivery();
  _testLateCloseListenerCanDisposeRuntime();
  _testChangedTextListenerFailureReportsAndContinuesDelivery();
  _testSessionCommitDelegatesToCommandPath();
  _testCommitPreservesTextAlignmentAnchor();
  _testDirectCommandCommitClearsActiveSession();
  _testDirectCommandCommitWithoutActiveSessionKeepsCloseStatePrivate();
  _testSessionNoOpCommitUsesCommandPath();
  _testCandidateStateReusedAndPrunedAfterCommit();
  _testStaleCandidateStatePruned();
  _testStaleCommitCleanup();
  _testDirectCommandStaleCommitClearsActiveSession();
  _testUnrelatedDocumentRevisionIsObservationOnly();
  _testUnrelatedDocumentRevisionPreservesSuppressionIdentity();
  _testPreparedTextFactsAreExactBeforeInstall();
  _testFailedPreparePreservesActiveSessionForRetry();
  _testValidationFailurePreservesActiveSession();
  _testSuccessfulLoadClearsActiveSession();
  _testFailedLoadPreservesActiveSession();
  _testDisposedRuntimeRejectsTextEditingPortOperations();
  _testDisposedRuntimeRejectsTextEditingSessionCallbacks();
}

void _testCandidateLookup() {
  test(
    'candidate lookup observes request without consuming or mutating',
    () async {
      final scenario = _Scenario();
      try {
        final request = await scenario.issueTextRequest();
        final beforeRevision = scenario.root.state.value.revisions.document;

        final candidate = scenario.root.textEditing.sessionCandidateFor(
          request,
        );

        _expectInitialCandidate(candidate, request);
        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        _expectRequestFactsLive(scenario.root, request);
        expect(scenario.root.state.value.revisions.document, beforeRevision);
        expect(_textValue(scenario.root), 'hello');
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _testNonTextCandidateLookup() {
  test('non-text context requests do not start text editing', () async {
    final scenario = _Scenario();
    try {
      _expectNonTextRequestRejected(
        scenario,
        await scenario.issueRectRequest(),
      );
      _expectNonTextRequestRejected(
        scenario,
        await scenario.issueEmptyCanvasRequest(),
      );
      expect(scenario.root.textEditing.activeSession.value, isNull);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testReadOnlyAdmission() {
  test('read-only admission preserves request facts', () async {
    final scenario = _Scenario();
    try {
      scenario.root.textEditing.setReadOnly(true);
      final readOnlyRequest = await scenario.issueTextRequest();
      final readOnlyCandidate = scenario.root.textEditing.sessionCandidateFor(
        readOnlyRequest,
      );
      expect(
        scenario.root.textEditing.start(_expectSession(readOnlyCandidate)),
        isNull,
      );
      expect(scenario.root.textEditing.activeSession.value, isNull);
      _expectRequestFactsLive(scenario.root, readOnlyRequest);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testSingleActiveAdmission() {
  test('single-active admission preserves competing request facts', () async {
    final scenario = _Scenario();
    try {
      final firstSession = await _startIdempotentTextSession(scenario);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNotNull);

      await _expectCompetingRequestRejected(scenario, firstSession);

      scenario.root.textEditing.setReadOnly(true);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(_textValue(scenario.root), 'hello');
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testRuntimeUsesMeasuredLayoutBoundary() {
  test('runtime text editing does not own text measurement', () {
    final source = File('lib/src/runtime/runtime_root.dart').readAsStringSync();

    expect(source, contains('FrameTextLayoutMeasurer'));
    expect(source, contains('MeasuredTextLayoutInput'));
    expect(source, contains('measureTextLayout'));
    expect(source, isNot(contains('TextPainter')));
    expect(source, isNot(contains('text.length')));
  });
}

void _testActiveSessionPublishesLiveUpdates() {
  test(
    'active session listeners are notified when live text changes',
    () async {
      final scenario = _Scenario();
      var notifications = 0;
      void listener() {
        notifications += 1;
      }

      scenario.root.textEditing.activeSession.addListener(listener);
      try {
        final session = await _startTextSession(scenario);
        notifications = 0;

        session.updateText('listener update');

        expect(session.liveText, 'listener update');
        expect(notifications, 1);

        session.updateText('listener update');

        expect(session.liveText, 'listener update');
        expect(notifications, 1);
      } finally {
        scenario.root.textEditing.activeSession.removeListener(listener);
        await scenario.dispose();
      }
    },
  );
}

// The complete outer/listener/nested trace stays in one test so its required
// causal order and matching-session replacement stay auditable instead of being
// hidden across setup helpers; splitting the branches would obscure the order.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void _testChangedTextListenerRunsAfterOuterDelivery() {
  test(
    'changed-text close notifies after outer delivery and preserves a listener session',
    () async {
      final trace = <String>[];
      final actions = <CanvasActionCommitted>[];
      late final RuntimeRoot root;
      late CanvasTextEditSession outerSession;
      late CanvasInteractionRequestId requestId;
      late CanvasContextActionRequested replacementRequest;
      CanvasTextEditSession? replacementSession;
      var committing = false;
      var listenerIsRunning = false;
      var interactionRevisionAtListener = -1;
      var outerInteractionRevisionAtState = -1;

      root = runtimeRootWithCommittedDocumentSeed(
        _document(),
        commitEffectObserver: (_) {
          if (!committing) {
            return;
          }
          trace.add(listenerIsRunning ? 'nested-observer' : 'outer-observer');
        },
      );
      final surface = Object();
      root.attachSurface(surface);
      root.edits.edit((edit) {
        edit.addElement(
          CanvasTextElement(
            id: _replacementTextId,
            text: 'replacement',
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
            transform: CanvasTransform.translation(const Offset(200, 0)),
          ),
        );
      });
      final requests = <CanvasContextActionRequested>[];
      final requestSubscription = root.contextActionRequests.listen(
        requests.add,
      );
      root.surfaceFrameSignal.addListener(() {
        if (!committing) {
          return;
        }
        trace.add(listenerIsRunning ? 'nested-frame' : 'outer-frame');
        if (!listenerIsRunning) {
          expect(root.activeTextEditSuppressionForTesting, isNull);
          expect(root.textEditing.activeSession.value, isNull);
          expect(_textValue(root), 'outer text');
        }
      });
      root.state.addListener(() {
        if (!committing) {
          return;
        }
        trace.add(listenerIsRunning ? 'nested-state' : 'outer-state');
        if (!listenerIsRunning) {
          outerInteractionRevisionAtState =
              root.state.value.revisions.interaction;
        }
      });
      final actionSubscription = root.actions.listen((action) {
        if (!committing) {
          return;
        }
        actions.add(action);
        trace.add('outer-action');
      });
      // This listener keeps the complete public close/replacement causal trace
      // together; extracting its assertions would hide the ordering it proves.
      // ignore: halstead-volume
      void listener() {
        if (root.textEditing.activeSession.value != null) {
          return;
        }
        trace.add('listener');
        expect(_textValue(root), 'outer text');
        expect(root.interactionEngine.requestFactsFor(requestId), isNull);
        expect(root.activeTextEditSuppressionForTesting, isNull);
        expect(outerSession.isActive, isFalse);
        expect(trace, [
          'outer-frame',
          'outer-state',
          'outer-action',
          'outer-observer',
          'listener',
        ]);
        interactionRevisionAtListener = root.state.value.revisions.interaction;
        expect(interactionRevisionAtListener, outerInteractionRevisionAtState);

        listenerIsRunning = true;
        root.edits.edit((edit) {
          edit.addElement(
            CanvasRectElement(
              id: _listenerNestedRectId,
              size: const Size(8, 8),
            ),
          );
        });
        listenerIsRunning = false;
        listenerIsRunning = true;
        replacementSession = _expectSession(
          root.textEditing.startFromContextAction(replacementRequest),
        );
        listenerIsRunning = false;
        trace.add('listener-return');
      }

      root.textEditing.activeSession.addListener(listener);
      try {
        root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
        await Future<void>.delayed(Duration.zero);
        final request = requests.single;
        requestId = request.requestId;
        root.handleDoubleTap(position: const Offset(200, 0), timestampMs: 2);
        await Future<void>.delayed(Duration.zero);
        replacementRequest = requests.last;
        final session = _expectSession(
          root.textEditing.startFromContextAction(request),
        );
        outerSession = session;
        session.updateText('outer text');

        committing = true;
        expect(session.commit(timestampMs: 77), isTrue);
        committing = false;

        expect(trace, [
          'outer-frame',
          'outer-state',
          'outer-action',
          'outer-observer',
          'listener',
          'nested-frame',
          'nested-state',
          'nested-observer',
          'nested-frame',
          'nested-state',
          'listener-return',
        ]);
        expect(session.isActive, isFalse);
        expect(_textValue(root), 'outer text');
        expect(_containsElement(root, _listenerNestedRectId), isTrue);
        expect(root.textEditing.activeSession.value, same(replacementSession));
        expect(
          root.interactionEngine.requestFactsFor(request.requestId),
          isNull,
        );
        expect(root.state.value.revisions.document, 3);
        expect(
          root.state.value.revisions.interaction,
          interactionRevisionAtListener + 1,
        );
        expect(actions, hasLength(1));
        final payload = actions.single.payload as CanvasTextEditActionPayload;
        expect(payload.requestId, request.requestId);
        expect(payload.nextTextLength, 'outer text'.length);
      } finally {
        root.textEditing.activeSession.removeListener(listener);
        await actionSubscription.cancel();
        await requestSubscription.cancel();
        root.detachSurface(surface);
        root.dispose();
      }
    },
  );
}

// The listener owns one complete close/dispose lifecycle so the accepted
// ordering, deferred notifier disposal, and rejected follow-up stay visible.
// ignore: halstead-volume, source-lines-of-code
void _testLateCloseListenerCanDisposeRuntime() {
  test(
    'changed-text close listener can dispose the runtime after outer delivery',
    () async {
      final scenario = _Scenario();
      late CanvasTextEditSession session;
      var closeNotifications = 0;
      void listener() {
        if (scenario.root.textEditing.activeSession.value != null) {
          return;
        }
        closeNotifications += 1;
        expect(_textValue(scenario.root), 'disposed from close listener');
        expect(scenario.actions, hasLength(1));
        expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
        expect(session.isActive, isFalse);
        scenario.root.dispose();
      }

      scenario.root.textEditing.activeSession.addListener(listener);
      try {
        final request = await scenario.issueTextRequest();
        session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('disposed from close listener');

        expect(session.commit(timestampMs: 79), isTrue);

        expect(closeNotifications, 1);
        expect(_textValue(scenario.root), 'disposed from close listener');
        expect(scenario.actions, hasLength(1));
        expect(scenario.root.dispose, returnsNormally);
        expect(
          () => scenario.root.edits.edit(
            (edit) => edit.addElement(
              CanvasRectElement(
                id: CanvasElementId('disposed-close-listener-mutation'),
                size: const Size(1, 1),
              ),
            ),
          ),
          throwsA(isA<StateError>()),
        );
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// The notifier/reporter failure and later delivery/guard probe form one
// containment proof; splitting them would obscure the required continuation.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testChangedTextListenerFailureReportsAndContinuesDelivery() {
  test(
    'changed-text listener and reporter failures do not escape an accepted commit',
    () async {
      final trace = <String>[];
      final errors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      late final RuntimeRoot root;
      var committing = false;
      final listenerFailure = StateError('active-session listener failed');
      final reporterFailure = StateError('active-session reporter failed');
      void throwingReporter(FlutterErrorDetails details) {
        errors.add(details);
        throw reporterFailure;
      }

      root = runtimeRootWithCommittedDocumentSeed(
        _document(),
        commitEffectObserver: (_) {
          if (committing) {
            trace.add('outer-observer');
          }
        },
      );
      final surface = Object();
      root.attachSurface(surface);
      final requests = <CanvasContextActionRequested>[];
      final requestSubscription = root.contextActionRequests.listen(
        requests.add,
      );
      root.surfaceFrameSignal.addListener(() {
        if (committing) {
          trace.add('outer-frame');
        }
      });
      root.state.addListener(() {
        if (committing) {
          trace.add('outer-state');
        }
      });
      final actions = <CanvasActionCommitted>[];
      final actionSubscription = root.actions.listen((action) {
        if (committing) {
          actions.add(action);
          trace.add('outer-action');
        }
      });
      void listener() {
        if (root.textEditing.activeSession.value == null) {
          throw listenerFailure;
        }
      }

      root.textEditing.activeSession.addListener(listener);
      try {
        root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
        await Future<void>.delayed(Duration.zero);
        final request = requests.single;
        final session = _expectSession(
          root.textEditing.startFromContextAction(request),
        );
        session.updateText('failure retained');

        committing = true;
        FlutterError.onError = throwingReporter;
        expect(session.commit(timestampMs: 78), isTrue);
        committing = false;

        expect(FlutterError.onError, same(throwingReporter));
        expect(errors, hasLength(1));
        expect(errors.single.exception, same(listenerFailure));
        expect(trace, [
          'outer-frame',
          'outer-state',
          'outer-action',
          'outer-observer',
        ]);
        expect(_textValue(root), 'failure retained');
        expect(session.isActive, isFalse);
        expect(root.textEditing.activeSession.value, isNull);
        expect(
          root.interactionEngine.requestFactsFor(request.requestId),
          isNull,
        );
        expect(root.state.value.revisions.document, 1);
        expect(root.state.value.revisions.interaction, 2);
        expect(actions, hasLength(1));

        root.edits.edit((edit) {
          edit.addElement(
            CanvasRectElement(
              id: _listenerFailureRectId,
              size: const Size(6, 6),
            ),
          );
        });
        expect(_containsElement(root, _listenerFailureRectId), isTrue);
      } finally {
        root.textEditing.activeSession.removeListener(listener);
        await actionSubscription.cancel();
        await requestSubscription.cancel();
        root.detachSurface(surface);
        FlutterError.onError = previousErrorHandler;
        root.dispose();
      }
    },
  );
}

void _testLiveUpdateRemeasuresGeometry() {
  test('live update remeasures geometry without document mutation', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      final beforeHeight = session.geometry.editBoundsWorld.height;

      session.updateText('hello\nworld');

      expect(session.liveText, 'hello\nworld');
      expect(
        session.geometry.editBoundsWorld.height,
        greaterThan(beforeHeight),
      );
      expect(_textValue(scenario.root), 'hello');
      expect(scenario.root.state.value.revisions.document, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testLiveGeometryPreservesTextAlignmentAnchor() {
  test(
    'live geometry preserves the aligned text anchor before commit',
    () async {
      await _expectLiveGeometryPreservesAnchorFor(TextAlign.left);
      await _expectLiveGeometryPreservesAnchorFor(TextAlign.right);
      await _expectLiveGeometryPreservesAnchorFor(TextAlign.center);

      expect(TextAlign.values, contains(TextAlign.center));
    },
  );
}

void _testSessionCommitDelegatesToCommandPath() {
  test('session commit delegates to guarded command path', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      session.updateText('updated');

      expect(session.commit(timestampMs: 42), isTrue);

      expect(_textValue(scenario.root), 'updated');
      expect(scenario.actions, hasLength(1));
      final payload =
          scenario.actions.single.payload as CanvasTextEditActionPayload;
      expect(payload.requestId, request.requestId);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNull,
      );
    } finally {
      await scenario.dispose();
    }
  });
}

void _testCommitPreservesTextAlignmentAnchor() {
  test('commit preserves the aligned text anchor when width changes', () async {
    await _expectCommitPreservesAnchorFor(TextAlign.left);
    await _expectCommitPreservesAnchorFor(TextAlign.right);
    await _expectCommitPreservesAnchorFor(TextAlign.center);

    expect(TextAlign.values, contains(TextAlign.center));
  });
}

void _testDirectCommandCommitClearsActiveSession() {
  test('direct command commit clears matching active session', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      expect(
        scenario.root.commands.commitTextEdit(
          request.requestId,
          'command update',
        ),
        isTrue,
      );

      expect(_textValue(scenario.root), 'command update');
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(session.isActive, isFalse);
    } finally {
      await scenario.dispose();
    }
  });
}

// One route owns the listener, revision, document, and action observations:
// splitting them would hide that a direct commit has no close side effect.
// The direct-command assertion deliberately keeps the prepared-pair observer,
// commit, and public result together; extracting it would hide the ownership
// boundary that proves direct TextEdit seals action lengths from that pair.
// ignore: source-lines-of-code, halstead-volume
void _testDirectCommandCommitWithoutActiveSessionKeepsCloseStatePrivate() {
  test(
    'direct command commit without an active session does not notify close listeners',
    () async {
      final scenario = _Scenario();
      var activeSessionNotifications = 0;
      void listener() {
        activeSessionNotifications += 1;
      }

      scenario.root.textEditing.activeSession.addListener(listener);
      try {
        final request = await scenario.issueTextRequest();
        final interactionRevisionBeforeCommit =
            scenario.root.state.value.revisions.interaction;
        final projected = <StoreAffectedElementProjection>[];

        expect(scenario.root.textEditing.activeSession.value, isNull);
        expect(
          DocumentStoreKernel.observeAffectedElementProjection(
            projected.add,
            () => scenario.root.commands.commitTextEdit(
              request.requestId,
              'direct command update',
            ),
          ),
          isTrue,
        );

        expect(activeSessionNotifications, 0);
        expect(
          scenario.root.state.value.revisions.interaction,
          interactionRevisionBeforeCommit,
        );
        expect(scenario.root.state.value.revisions.document, 1);
        expect(_textValue(scenario.root), 'direct command update');
        expect(scenario.actions, hasLength(1));
        final payload =
            scenario.actions.single.payload as CanvasTextEditActionPayload;
        expect(payload.requestId, request.requestId);
        expect(projected, hasLength(1));
        final before = _asTextElement(projected.single.before);
        final after = _asTextElement(projected.single.after);
        expect(payload.previousTextLength, before.text.length);
        expect(payload.nextTextLength, after.text.length);
      } finally {
        scenario.root.textEditing.activeSession.removeListener(listener);
        await scenario.dispose();
      }
    },
  );
}

Future<void> _expectLiveGeometryPreservesAnchorFor(TextAlign align) async {
  final scenario = _Scenario(document: _document(align: align, maxWidth: null));
  try {
    final request = await scenario.issueTextRequest();
    final session = _expectSession(
      scenario.root.textEditing.startFromContextAction(request),
    );
    final beforeAnchor = _anchorValueFor(
      session.geometry.editBoundsWorld,
      align,
    );
    final beforeTop = session.geometry.editBoundsWorld.top;

    session.updateText('hello with more text\nsecond line');

    final liveAnchor = _anchorValueFor(session.geometry.editBoundsWorld, align);
    expect(liveAnchor, moreOrLessEquals(beforeAnchor, epsilon: 0.001));
    expect(
      session.geometry.editBoundsWorld.top,
      moreOrLessEquals(beforeTop, epsilon: 0.001),
    );
    expect(_textValue(scenario.root), 'hello');
  } finally {
    await scenario.dispose();
  }
}

Future<void> _expectCommitPreservesAnchorFor(TextAlign align) async {
  final scenario = _Scenario(document: _document(align: align, maxWidth: null));
  try {
    final request = await scenario.issueTextRequest();
    final session = _expectSession(
      scenario.root.textEditing.startFromContextAction(request),
    );
    final beforeAnchor = _anchorValueFor(
      session.geometry.editBoundsWorld,
      align,
    );
    final beforeTop = session.geometry.editBoundsWorld.top;

    session.updateText('hello with more text\nsecond line');
    expect(session.commit(timestampMs: 43), isTrue);

    final nextRequest = await scenario.issueTextRequest();
    final nextSession = _expectSession(
      scenario.root.textEditing.sessionCandidateFor(nextRequest),
    );
    final afterAnchor = _anchorValueFor(
      nextSession.geometry.editBoundsWorld,
      align,
    );
    expect(afterAnchor, moreOrLessEquals(beforeAnchor, epsilon: 0.001));
    expect(
      nextSession.geometry.editBoundsWorld.top,
      moreOrLessEquals(beforeTop, epsilon: 0.001),
    );
  } finally {
    await scenario.dispose();
  }
}

double _anchorValueFor(Rect bounds, TextAlign align) {
  return switch (align) {
    TextAlign.left || TextAlign.start || TextAlign.justify => bounds.left,
    TextAlign.right || TextAlign.end => bounds.right,
    TextAlign.center => bounds.center.dx,
  };
}

void _testSessionNoOpCommitUsesCommandPath() {
  test('session no-op commit consumes request without action', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      expect(session.commit(timestampMs: 44), isTrue);

      expect(_textValue(scenario.root), 'hello');
      expect(scenario.actions, isEmpty);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNull,
      );
    } finally {
      await scenario.dispose();
    }
  });
}

void _testCandidateStateReusedAndPrunedAfterCommit() {
  test('candidate state is reused and pruned after request commit', () async {
    final scenario = _Scenario();
    try {
      final candidate = await _expectRepeatedCandidateReuse(scenario);

      expect(scenario.root.textEditing.start(candidate), same(candidate));
      expect(candidate.commit(timestampMs: 45), isTrue);
      expect(scenario.root.textEditCandidateStateCountForTesting, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testStaleCandidateStatePruned() {
  test('stale candidate state is pruned during candidate lookup', () async {
    final scenario = _Scenario();
    try {
      final staleRequest = await scenario.issueTextRequest();
      expect(
        scenario.root.textEditing.sessionCandidateFor(staleRequest),
        isNotNull,
      );
      expect(scenario.root.textEditCandidateStateCountForTesting, 1);

      _makeTextRequestStale(scenario);

      expect(
        scenario.root.textEditing.sessionCandidateFor(staleRequest),
        isNull,
      );
      expect(scenario.root.textEditCandidateStateCountForTesting, 0);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testStaleCommitCleanup() {
  test('stale commit clears transient session without mutation', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      _makeTextRequestStale(scenario);
      session.updateText('stale update');

      expect(session.isStale, isTrue);
      expect(session.commit(timestampMs: 43), isFalse);
      expect(_textValue(scenario.root), 'hello');
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(scenario.root.textEditCandidateStateCountForTesting, 0);
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testDirectCommandStaleCommitClearsActiveSession() {
  test('direct stale command clears matching active session', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      _makeTextRequestStale(scenario);

      expect(
        scenario.root.commands.commitTextEdit(request.requestId, 'stale'),
        isFalse,
      );

      expect(_textValue(scenario.root), 'hello');
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(session.isActive, isFalse);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testUnrelatedDocumentRevisionIsObservationOnly() {
  test('unrelated document revision does not stale active session', () async {
    final scenario = _Scenario();
    try {
      final session = await _startTextSession(scenario);
      _addUnrelatedRect(scenario);
      session.updateText('updated after unrelated edit');

      expect(session.isStale, isFalse);
      expect(session.documentRevision, 0);
      expect(scenario.root.state.value.revisions.document, 1);
      expect(session.commit(timestampMs: 48), isTrue);
      expect(_textValue(scenario.root), 'updated after unrelated edit');
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testUnrelatedDocumentRevisionPreservesSuppressionIdentity() {
  test('unrelated document revision preserves suppression identity', () async {
    final scenario = _Scenario();
    try {
      await _startTextSession(scenario);
      final before = scenario.root.activeTextEditSuppressionIdentityForTesting;

      _addUnrelatedRect(scenario);

      expect(scenario.root.state.value.revisions.document, 1);
      expect(scenario.root.activeTextEditSuppressionIdentityForTesting, before);
    } finally {
      await scenario.dispose();
    }
  });
}

// The projection witness keeps preparation, pre-install state, installed facts,
// and action sealing in one causal scenario; splitting it would hide the seam.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testPreparedTextFactsAreExactBeforeInstall() {
  test(
    'text action sealing reads the exact prepared pair before install',
    () async {
      final scenario = _Scenario(document: _richTextDocument());
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        final beforeDocument = scenario.root.readDocument();
        final beforeRevisions = scenario.root.state.value.revisions;
        final beforeSelection = scenario.root.selectedElementIds;
        final before = _textElement(scenario.root);
        final projected = <StoreAffectedElementProjection>[];
        final sparseTouchedReads = <(String? subject, String? side)>[];
        final layoutEvents = <(String, Color)>[];
        session.updateText('expanded\nprepared text');

        final didCommit = CommittedDocument.observeSparseCandidateEvents(
          (event) {
            if (event.kind.name == 'touchedElementRead') {
              sparseTouchedReads.add((event.subject, event.side?.name));
            }
          },
          () => FrameTextLayoutMeasurer.observeNewLayoutWork(
            (text, color) => layoutEvents.add((text, color)),
            () => DocumentStoreKernel.observeAffectedElementProjection(
              projected.add,
              () {
                final committed = scenario.root.readDocument();
                expect(committed, same(beforeDocument));
                expect(scenario.root.state.value.revisions, beforeRevisions);
                expect(scenario.root.selectedElementIds, beforeSelection);
                expect(scenario.actions, isEmpty);
                expect(session.isActive, isTrue);
                _expectRequestFactsLive(scenario.root, request);

                return session.commit(timestampMs: 61);
              },
            ),
          ),
        );

        expect(didCommit, isTrue);
        expect(projected, hasLength(1));
        final facts = projected.single;
        final projectedBefore = _asTextElement(facts.before);
        final projectedAfter = _asTextElement(facts.after);
        _expectCompleteTextElement(projectedBefore, before);
        final installed = _textElement(scenario.root);
        _expectCompleteTextElement(projectedAfter, installed);
        expect(projectedBefore.id, _textId);
        expect(projectedAfter.id, _textId);
        expect(projectedAfter.revision, projectedBefore.revision + 1);
        expect(projectedAfter.transform, isNot(projectedBefore.transform));
        expect(sparseTouchedReads, [
          (_textId.value, 'base'),
          (_textId.value, 'candidate'),
        ]);
        final action =
            scenario.actions.single.payload as CanvasTextEditActionPayload;
        expect(action.previousTextLength, projectedBefore.text.length);
        expect(action.nextTextLength, projectedAfter.text.length);
        expect(layoutEvents, [
          ('expanded\nprepared text', const Color(0xB3221144)),
        ]);
      } finally {
        await scenario.dispose();
      }
    },
  );
}

// The failed projection path must compare every still-live session owner before
// retry, so its assertions remain together rather than duplicating snapshots.
// ignore: halstead-volume
void _testFailedPreparePreservesActiveSessionForRetry() {
  test(
    'actual candidate projection failure preserves session for retry',
    () async {
      final scenario = _Scenario();
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('retryable');
        final beforeDocument = scenario.root.readDocument();
        final beforeRevisions = scenario.root.state.value.revisions;
        final beforeSelection = scenario.root.selectedElementIds;
        final failure = StateError('prepared text projection failed');

        expect(
          () => DocumentStoreKernel.injectAffectedElementProjectionFailure(
            failure,
            () => session.commit(timestampMs: 46),
          ),
          throwsA(same(failure)),
        );
        expect(scenario.root.readDocument(), same(beforeDocument));
        expect(scenario.root.state.value.revisions, beforeRevisions);
        expect(scenario.root.selectedElementIds, beforeSelection);
        expect(session.isActive, isTrue);
        expect(session.liveText, 'retryable');
        expect(scenario.root.textEditing.activeSession.value, same(session));
        expect(scenario.root.activeTextEditSuppressionForTesting, isNotNull);
        _expectRequestFactsLive(scenario.root, request);
        expect(scenario.actions, isEmpty);
        expect(session.commit(timestampMs: 47), isTrue);
        expect(_textValue(scenario.root), 'retryable');
        expect(scenario.actions, hasLength(1));
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _testValidationFailurePreservesActiveSession() {
  test(
    'validation failure preserves active session and request facts',
    () async {
      final scenario = _Scenario();
      try {
        final request = await scenario.issueTextRequest();
        final session = _expectSession(
          scenario.root.textEditing.startFromContextAction(request),
        );
        session.updateText('x' * 100001);

        expect(() => session.commit(), throwsA(isA<CanvasDataException>()));
        expect(scenario.root.textEditing.activeSession.value, same(session));
        expect(
          scenario.root.interactionEngine.requestFactsFor(request.requestId),
          isNotNull,
        );
        expect(_textValue(scenario.root), 'hello');
      } finally {
        await scenario.dispose();
      }
    },
  );
}

void _testSuccessfulLoadClearsActiveSession() {
  test('successful load clears active session and suppression token', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      scenario.root.edits.loadDocumentFromJson(
        encodeCanvasDocumentToJson(CanvasDocument()),
      );

      expect(session.isActive, isFalse);
      expect(scenario.root.textEditing.activeSession.value, isNull);
      expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
      expect(scenario.root.textEditCandidateStateCountForTesting, 0);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNull,
      );
      expect(scenario.actions, isEmpty);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testFailedLoadPreservesActiveSession() {
  test('failed load preserves active session and suppression token', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      expect(
        () => scenario.root.edits.loadDocumentFromJson(
          encodeCanvasDocumentToJson(_invalidReplacementDocument()),
        ),
        throwsA(isA<CanvasDataException>()),
      );

      expect(session.isActive, isTrue);
      expect(scenario.root.textEditing.activeSession.value, same(session));
      expect(scenario.root.activeTextEditSuppressionForTesting, isNotNull);
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNotNull,
      );
    } finally {
      await scenario.dispose();
    }
  });
}

void _testDisposedRuntimeRejectsTextEditingPortOperations() {
  test('disposed runtime rejects text editing port operations', () async {
    final scenario = _Scenario();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );

      scenario.root.dispose();

      final throwsDisposed = throwsA(isA<StateError>());
      expect(
        () => scenario.root.textEditing.sessionCandidateFor(request),
        throwsDisposed,
      );
      expect(() => scenario.root.textEditing.start(session), throwsDisposed);
      expect(
        () => scenario.root.textEditing.startFromContextAction(request),
        throwsDisposed,
      );
      expect(() => scenario.root.textEditing.setReadOnly(true), throwsDisposed);
      expect(() => scenario.root.textEditing.dismissActive(), throwsDisposed);
    } finally {
      await scenario.dispose();
    }
  });
}

void _testDisposedRuntimeRejectsTextEditingSessionCallbacks() {
  test('disposed runtime rejects text editing session callbacks', () async {
    final scenario = _Scenario();
    try {
      final session = await _startTextSession(scenario);

      scenario.root.dispose();

      final throwsDisposed = throwsA(isA<StateError>());
      expect(() => session.updateText('after dispose'), throwsDisposed);
      expect(() => session.commit(), throwsDisposed);
      expect(() => session.dismiss(), throwsDisposed);
      expect(() => session.isActive, throwsDisposed);
      expect(() => session.isStale, throwsDisposed);
      expect(() => session.geometry, throwsDisposed);
      expect(() => session.style, throwsDisposed);
      expect(() => session.liveText, throwsDisposed);
    } finally {
      await scenario.dispose();
    }
  });
}

CanvasTextEditSession _expectSession(CanvasTextEditSession? session) {
  expect(session, isNotNull);

  return session as CanvasTextEditSession;
}

Future<CanvasTextEditSession> _startTextSession(_Scenario scenario) async {
  final request = await scenario.issueTextRequest();
  final session = _expectSession(
    scenario.root.textEditing.startFromContextAction(request),
  );
  expect(scenario.root.textEditing.activeSession.value, same(session));

  return session;
}

Future<CanvasTextEditSession> _startIdempotentTextSession(
  _Scenario scenario,
) async {
  final request = await scenario.issueTextRequest();
  final session = _expectSession(
    scenario.root.textEditing.startFromContextAction(request),
  );
  expect(scenario.root.textEditing.start(session), same(session));
  expect(
    scenario.root.textEditing.startFromContextAction(request),
    same(session),
  );
  expect(scenario.root.textEditing.activeSession.value, same(session));

  return session;
}

Future<CanvasTextEditSession> _expectRepeatedCandidateReuse(
  _Scenario scenario,
) async {
  final request = await scenario.issueTextRequest();
  final first = _expectSession(
    scenario.root.textEditing.sessionCandidateFor(request),
  );
  final second = _expectSession(
    scenario.root.textEditing.sessionCandidateFor(request),
  );
  expect(second, same(first));
  expect(scenario.root.textEditCandidateStateCountForTesting, 1);

  return first;
}

Future<void> _expectCompetingRequestRejected(
  _Scenario scenario,
  CanvasTextEditSession activeSession,
) async {
  final request = await scenario.issueTextRequest();
  final candidate = scenario.root.textEditing.sessionCandidateFor(request);
  expect(scenario.root.textEditing.start(_expectSession(candidate)), isNull);
  expect(scenario.root.textEditing.activeSession.value, same(activeSession));
  _expectRequestFactsLive(scenario.root, request);
}

void _expectNonTextRequestRejected(
  _Scenario scenario,
  CanvasContextActionRequested request,
) {
  final beforeRevision = scenario.root.state.value.revisions.document;

  expect(scenario.root.textEditing.sessionCandidateFor(request), isNull);
  expect(scenario.root.textEditing.startFromContextAction(request), isNull);
  expect(scenario.root.textEditing.activeSession.value, isNull);
  expect(scenario.root.activeTextEditSuppressionForTesting, isNull);
  _expectRequestFactsLive(scenario.root, request);
  expect(scenario.root.state.value.revisions.document, beforeRevision);
  expect(_textValue(scenario.root), 'hello');
  expect(scenario.actions, isEmpty);
}

void _makeTextRequestStale(_Scenario scenario) {
  scenario.root.edits.edit(
    (edit) => edit.updateElement(
      CanvasTextElementUpdate(id: _textId, fontSize: const CanvasFieldSet(20)),
    ),
  );
}

void _addUnrelatedRect(_Scenario scenario) {
  scenario.root.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(
        id: CanvasElementId('unrelated-rect'),
        size: const Size(10, 10),
      ),
    );
  });
}

void _expectInitialCandidate(
  CanvasTextEditSession? candidate,
  CanvasContextActionRequested request,
) {
  final session = _expectSession(candidate);
  expect(session.isActive, isFalse);
  expect(session.isStale, isFalse);
  expect(session.requestId, request.requestId);
  expect(session.elementId, _textId);
  expect(session.initialText, 'hello');
  expect(session.liveText, 'hello');
  expect(session.geometry.editBoundsWorld.width, greaterThan(0));
  expect(session.style.fontSize, 16);
}

void _expectRequestFactsLive(
  RuntimeRoot root,
  CanvasContextActionRequested request,
) {
  expect(root.interactionEngine.requestFactsFor(request.requestId), isNotNull);
}

final class _Scenario {
  _Scenario({CanvasDocument? document})
    : root = runtimeRootWithCommittedDocumentSeed(document ?? _document()) {
    actionSubscription = root.actions.listen(actions.add);
    requestSubscription = root.contextActionRequests.listen(requests.add);
  }

  final RuntimeRoot root;
  late final StreamSubscription<CanvasActionCommitted> actionSubscription;
  late final StreamSubscription<CanvasContextActionRequested>
  requestSubscription;
  final List<CanvasActionCommitted> actions = [];
  final List<CanvasContextActionRequested> requests = [];
  var _disposed = false;

  Future<CanvasContextActionRequested> issueTextRequest() {
    root.handleDoubleTap(position: Offset.zero, timestampMs: 1);

    return _takeRequest();
  }

  Future<CanvasContextActionRequested> issueRectRequest() {
    root.handleDoubleTap(position: const Offset(130, 0), timestampMs: 1);

    return _takeRequest();
  }

  Future<CanvasContextActionRequested> issueEmptyCanvasRequest() {
    root.handleDoubleTap(position: const Offset(300, 300), timestampMs: 1);

    return _takeRequest();
  }

  Future<CanvasContextActionRequested> _takeRequest() async {
    await Future<void>.delayed(Duration.zero);
    final request = requests.single;
    requests.clear();
    actions.clear();

    return request;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await actionSubscription.cancel();
    await requestSubscription.cancel();
    root.dispose();
  }
}

String _textValue(RuntimeRoot root) {
  return _textElement(root).text;
}

CanvasTextElement _textElement(RuntimeRoot root) {
  final text = root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasTextElement>()
      .singleWhere((element) => element.id == _textId);

  return text;
}

CanvasTextElement _asTextElement(CanvasElement element) {
  if (element is! CanvasTextElement) {
    throw StateError('Expected a text element projection.');
  }
  return element;
}

// One complete field comparison prevents a future text request from omitting a
// common, nullable, formatting, or sizing fact behind smaller partial checks.
// ignore: halstead-volume
void _expectCompleteTextElement(
  CanvasTextElement actual,
  CanvasTextElement expected,
) {
  expect(actual.id, expected.id);
  expect(actual.revision, expected.revision);
  expect(actual.transform, expected.transform);
  expect(actual.opacity, expected.opacity);
  expect(actual.hitPadding, expected.hitPadding);
  expect(actual.isVisible, expected.isVisible);
  expect(actual.isSelectable, expected.isSelectable);
  expect(actual.isLocked, expected.isLocked);
  expect(actual.isDeletable, expected.isDeletable);
  expect(actual.isTransformable, expected.isTransformable);
  expect(actual.metadata, expected.metadata);
  expect(actual.text, expected.text);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.color, expected.color);
  expect(actual.align, expected.align);
  expect(actual.textDirection, expected.textDirection);
  expect(actual.isBold, expected.isBold);
  expect(actual.isItalic, expected.isItalic);
  expect(actual.isUnderline, expected.isUnderline);
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.maxWidth, expected.maxWidth);
  expect(actual.lineHeight, expected.lineHeight);
}

bool _containsElement(RuntimeRoot root, CanvasElementId id) {
  return root.readDocument().layers.any(
    (layer) => layer.elements.any((element) => element.id == id),
  );
}

CanvasDocument _document({
  TextAlign align = TextAlign.left,
  double? maxWidth = 120,
}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: _textId,
            text: 'hello',
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
            align: align,
            maxWidth: maxWidth,
          ),
          CanvasRectElement(
            id: _rectId,
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(120, 0)),
          ),
        ],
      ),
    ],
  );
}

// This fixture intentionally spells out every persisted text/common field so
// the prepared pair has an independent complete expected value.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _richTextDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: _textId,
            text: 'hello',
            revision: 7,
            fontSize: 18,
            color: const Color(0xFF221144),
            align: TextAlign.right,
            textDirection: TextDirection.rtl,
            isBold: true,
            isItalic: true,
            isUnderline: true,
            fontFamily: 'Inter',
            maxWidth: null,
            lineHeight: 1.25,
            transform: CanvasTransform.translation(const Offset(0, 15)),
            opacity: 0.7,
            hitPadding: 3,
            isVisible: true,
            isSelectable: true,
            isLocked: false,
            isDeletable: false,
            isTransformable: false,
            metadata: CanvasMetadata.fromMap({
              'label': 'rich',
              'nullable': null,
            }),
          ),
          CanvasRectElement(
            id: _rectId,
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(220, 0)),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _invalidReplacementDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: _textId,
            text: 'replacement',
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
          CanvasTextElement(
            id: _textId,
            text: 'duplicate',
            color: const Color(0xFF222222),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    ],
  );
}

final _textId = CanvasElementId('text-a');
final _replacementTextId = CanvasElementId('replacement-text');
final _rectId = CanvasElementId('rect-a');
final _listenerNestedRectId = CanvasElementId('listener-nested-rect');
final _listenerFailureRectId = CanvasElementId('listener-failure-rect');
