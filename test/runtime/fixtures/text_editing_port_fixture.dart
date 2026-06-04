import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _testCandidateLookup();
  _testNonTextCandidateLookup();
  _testReadOnlyAdmission();
  _testSingleActiveAdmission();
  _testLiveUpdateRemeasuresGeometry();
  _testRuntimeUsesMeasuredLayoutBoundary();
  _testActiveSessionPublishesLiveUpdates();
  _testSessionCommitDelegatesToCommandPath();
  _testDirectCommandCommitClearsActiveSession();
  _testSessionNoOpCommitUsesCommandPath();
  _testCandidateStateReusedAndPrunedAfterCommit();
  _testStaleCandidateStatePruned();
  _testStaleCommitCleanup();
  _testDirectCommandStaleCommitClearsActiveSession();
  _testUnrelatedDocumentRevisionIsObservationOnly();
  _testUnrelatedDocumentRevisionPreservesSuppressionIdentity();
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
      } finally {
        scenario.root.textEditing.activeSession.removeListener(listener);
        await scenario.dispose();
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

void _testFailedPreparePreservesActiveSessionForRetry() {
  test('failed prepare preserves active session for retry', () async {
    final scenario = _Scenario.failedTextPrepare();
    try {
      final request = await scenario.issueTextRequest();
      final session = _expectSession(
        scenario.root.textEditing.startFromContextAction(request),
      );
      session.updateText('retryable');

      expect(session.commit(timestampMs: 46), isFalse);
      expect(session.isActive, isTrue);
      expect(scenario.root.textEditing.activeSession.value, same(session));
      expect(scenario.root.activeTextEditSuppressionForTesting, isNotNull);
      _expectRequestFactsLive(scenario.root, request);
    } finally {
      await scenario.dispose();
    }
  });
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

      scenario.root.edits.loadDocument(CanvasDocument());

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
        () => scenario.root.edits.loadDocument(_invalidReplacementDocument()),
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
  _Scenario()
    : root = RuntimeRoot(
        initialDocument: _document(),
        config: const CanvasRuntimeConfig(),
      ) {
    actionSubscription = root.actions.listen(actions.add);
    requestSubscription = root.contextActionRequests.listen(requests.add);
  }

  _Scenario.failedTextPrepare()
    : root = RuntimeRoot.test(
        initialDocument: _document(),
        config: const CanvasRuntimeConfig(),
        textEditPrepareOverride: (_) {
          return CommitDeliveryResult(shouldPublishState: false);
        },
      ) {
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
  final text = root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasTextElement>()
      .single;

  return text.text;
}

CanvasDocument _document() {
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
            maxWidth: 120,
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
final _rectId = CanvasElementId('rect-a');
