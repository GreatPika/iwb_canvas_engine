import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_request_registry.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('unknown, invalid, and stale text requests are rejected', () {
    return expectLater(_verifyRejectedRequests(), completes);
  });

  test('generation mismatch retires text requests', () {
    return expectLater(
      Future<void>.sync(_verifyGenerationMismatchRetiresRequest),
      completes,
    );
  });

  test('same-text and changed text requests retire correctly', () {
    return expectLater(_verifyAcceptedRequests(), completes);
  });

  test('text validation runs before request retirement', () {
    return expectLater(_verifyValidationBeforeRetirement(), completes);
  });

  test('disposed runtime rejects before request consumption', () {
    return expectLater(_verifyDisposedRuntimeBehavior(), completes);
  });
}

Future<void> _verifyRejectedRequests() async {
  await _expectCommitFalse(_unknownRequestScenario());
  await _expectCommitFalse(_emptyRequestScenario());
  await _expectCommitFalse(_rectRequestScenario());
  await _expectCommitFalse(_missingTextScenario());
  await _expectCommitFalse(_epochStaleScenario());
  await _expectCommitFalse(_revisionStaleScenario());
  await _expectCommitFalse(_familyStaleScenario());
}

void _verifyGenerationMismatchRetiresRequest() {
  final readPort = _TextGuardReadPort(
    textGuardFacts: TextCommitGuardReadFacts.current(
      targetElementId: _textId,
      targetKind: CanvasElementKind.text,
      generation: 2,
      elementRevision: 0,
      family: InteractionElementFamily.text,
      controllerEpoch: 1,
      documentRevision: 1,
      currentText: 'hello',
    ),
  );
  final engine = _textGuardEngine(readPort);
  final requestId = _issueTextRequest(engine);

  expect(
    engine.textEditGuardDecision(requestId).kind,
    TextEditGuardDecisionKind.rejectedAndRetired,
  );
  expect(
    engine.textEditGuardDecision(requestId).kind,
    TextEditGuardDecisionKind.unknownOrRetired,
  );
  expect(readPort.textGuardReads, 1);
}

Future<void> _expectCommitFalse(Future<_IssuedScenario> future) async {
  final scenario = await future;
  try {
    expect(
      scenario.root.commands.commitTextEdit(
        scenario.requestId,
        'updated',
        timestampMs: 9,
      ),
      isFalse,
    );
    expect(scenario.actions, isEmpty);
    expect(_textValueOrNull(scenario.root), isNot('updated'));
  } finally {
    await scenario.dispose();
  }
}

Future<_IssuedScenario> _unknownRequestScenario() async {
  final scenario = _Scenario();

  return scenario.issued(CanvasInteractionRequestId('unknown-request'));
}

Future<_IssuedScenario> _emptyRequestScenario() async {
  final scenario = _Scenario();
  final requestId = await scenario.issueRequestAt(const Offset(300, 300));

  return scenario.issued(requestId);
}

Future<_IssuedScenario> _rectRequestScenario() async {
  final scenario = _Scenario();
  final requestId = await scenario.issueRequestAt(const Offset(0, 0));

  return scenario.issued(requestId);
}

Future<_IssuedScenario> _missingTextScenario() async {
  final scenario = _Scenario();
  final requestId = await scenario.issueTextRequest();
  scenario.root.edits.edit((edit) => edit.removeElement(_textId));

  return scenario.issued(requestId);
}

Future<_IssuedScenario> _epochStaleScenario() async {
  final scenario = _Scenario();
  final requestId = await scenario.issueTextRequest();
  scenario.root.edits.loadDocument(_document());

  return scenario.issued(requestId);
}

Future<_IssuedScenario> _revisionStaleScenario() async {
  final scenario = _Scenario();
  final requestId = await scenario.issueTextRequest();
  scenario.root.edits.edit(
    (edit) => edit.updateElement(
      CanvasTextElementUpdate(id: _textId, fontSize: const CanvasFieldSet(30)),
    ),
  );

  return scenario.issued(requestId);
}

Future<_IssuedScenario> _familyStaleScenario() async {
  final scenario = _Scenario();
  final requestId = await scenario.issueTextRequest();
  scenario.root.edits.edit((edit) {
    edit
      ..removeElement(_textId)
      ..addElement(CanvasRectElement(id: _textId, size: const Size(10, 10)));
  });

  return scenario.issued(requestId);
}

Future<void> _verifyAcceptedRequests() async {
  await _expectSameTextCommitRetiresPrivately();
  await _expectUnrelatedDocumentRevisionIsObservationOnly();
  await _expectChangedTextCommitPublishesAction();
}

Future<void> _expectSameTextCommitRetiresPrivately() async {
  final sameText = _Scenario();
  try {
    final requestId = await sameText.issueTextRequest();
    expect(sameText.root.commands.commitTextEdit(requestId, 'hello'), isTrue);
    expect(sameText.root.commands.commitTextEdit(requestId, 'again'), isFalse);
    expect(sameText.actions, isEmpty);
    expect(sameText.stateEvents, isEmpty);
  } finally {
    await sameText.dispose();
  }
}

Future<void> _expectUnrelatedDocumentRevisionIsObservationOnly() async {
  final scenario = _Scenario();
  try {
    final requestId = await scenario.issueTextRequest();
    scenario.root.edits.edit((edit) {
      edit.addElement(
        CanvasRectElement(
          id: CanvasElementId('unrelated-rect'),
          size: const Size(10, 10),
        ),
      );
    });
    scenario.clearPublicEvents();

    expect(
      scenario.root.commands.commitTextEdit(
        requestId,
        'updated',
        timestampMs: 12,
      ),
      isTrue,
    );
    expect(_textValueOrNull(scenario.root), 'updated');
  } finally {
    await scenario.dispose();
  }
}

Future<void> _expectChangedTextCommitPublishesAction() async {
  final changed = _Scenario();
  try {
    final requestId = await changed.issueTextRequest();
    final deliveryEvents = <String>[];
    changed.recordDeliveryFor(requestId, deliveryEvents);
    expect(
      changed.root.commands.commitTextEdit(
        requestId,
        'updated',
        timestampMs: 12,
      ),
      isTrue,
    );
    expect(changed.stateEvents, hasLength(1));
    expect(changed.actions, hasLength(1));
    expect(deliveryEvents, ['state', 'actionRetired']);
    _expectEditTextAction(changed.actions.single, requestId);
    expect(_textValueOrNull(changed.root), 'updated');
    expect(changed.root.commands.commitTextEdit(requestId, 'retry'), isFalse);
  } finally {
    await changed.dispose();
  }
}

void _expectEditTextAction(
  CanvasActionCommitted action,
  CanvasInteractionRequestId requestId,
) {
  expect(action.type, CanvasActionType.editText);
  expect(action.elementIds, [_textId]);
  expect(action.timestampMs, 12);
  final payload = action.payload as CanvasTextEditActionPayload;
  expect(payload.requestId, requestId);
  expect(payload.previousTextLength, 5);
  expect(payload.nextTextLength, 7);
}

Future<void> _verifyValidationBeforeRetirement() async {
  final scenario = _Scenario();
  try {
    final requestId = await scenario.issueTextRequest();
    expect(
      () => scenario.root.commands.commitTextEdit(requestId, 'x' * 100001),
      throwsA(isA<CanvasDataException>()),
    );
    expect(scenario.root.commands.commitTextEdit(requestId, 'valid'), isTrue);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyDisposedRuntimeBehavior() async {
  final scenario = _Scenario();
  final requestId = await scenario.issueTextRequest();
  await scenario.dispose();

  expect(
    () => scenario.root.commands.commitTextEdit(requestId, 'updated'),
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        'CanvasRuntime is disposed.',
      ),
    ),
  );
}

String? _textValueOrNull(RuntimeRoot root) {
  for (final element in root.readDocument().layers.single.elements) {
    if (element is CanvasTextElement && element.id == _textId) {
      return element.text;
    }
  }

  return null;
}

final class _Scenario {
  _Scenario() {
    root = RuntimeRoot(
      initialDocument: _document(),
      config: const CanvasRuntimeConfig(),
    );
    actionSubscription = root.actions.listen((action) {
      actions.add(action);
      _onAction?.call(action);
    });
    root.state.addListener(() {
      final state = root.state.value;
      stateEvents.add(state);
      _onState?.call(state);
    });
    requestSubscription = root.contextActionRequests.listen(requests.add);
  }

  late final RuntimeRoot root;
  late final StreamSubscription<CanvasActionCommitted> actionSubscription;
  late final StreamSubscription<CanvasContextActionRequested>
  requestSubscription;
  final List<CanvasActionCommitted> actions = [];
  final List<CanvasRuntimeState> stateEvents = [];
  final List<CanvasContextActionRequested> requests = [];
  void Function(CanvasActionCommitted action)? _onAction;
  void Function(CanvasRuntimeState state)? _onState;
  var _disposed = false;

  Future<CanvasInteractionRequestId> issueTextRequest() {
    return issueRequestAt(const Offset(120, 0));
  }

  Future<CanvasInteractionRequestId> issueRequestAt(Offset position) async {
    root.handleDoubleTap(position: position, timestampMs: 1);
    await Future<void>.delayed(Duration.zero);
    final requestId = requests.single.requestId;
    requests.clear();
    actions.clear();
    stateEvents.clear();

    return requestId;
  }

  void clearPublicEvents() {
    actions.clear();
    stateEvents.clear();
  }

  void recordDeliveryFor(
    CanvasInteractionRequestId requestId,
    List<String> events,
  ) {
    _onState = (_) {
      events.add('state');
    };
    _onAction = (_) {
      expect(
        root.interactionEngine.requestFactsFor(requestId)?.retired,
        isTrue,
      );
      events.add('actionRetired');
    };
  }

  _IssuedScenario issued(CanvasInteractionRequestId requestId) {
    return _IssuedScenario(root: root, requestId: requestId, owner: this);
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

final class _IssuedScenario {
  const _IssuedScenario({
    required this.root,
    required this.requestId,
    required _Scenario owner,
  }) : _owner = owner;

  final RuntimeRoot root;
  final CanvasInteractionRequestId requestId;
  final _Scenario _owner;

  List<CanvasActionCommitted> get actions => _owner.actions;

  Future<void> dispose() {
    return _owner.dispose();
  }
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
          ),
          CanvasTextElement(
            id: _textId,
            text: 'hello',
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
            transform: CanvasTransform.translation(const Offset(120, 0)),
          ),
        ],
      ),
    ],
  );
}

final CanvasElementId _textId = CanvasElementId('text-a');

InteractionEngine _textGuardEngine(_TextGuardReadPort readPort) {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle.defaultStyle,
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
  )..attachReadPort(readPort);
}

CanvasInteractionRequestId _issueTextRequest(InteractionEngine engine) {
  final request = engine.handleDoubleTap(
    const Offset(120, 0),
    InteractionPointerContext(
      viewCameraOffset: Offset.zero,
      controllerEpoch: 1,
      resolveOutputTimestamp: (hint) => hint ?? 0,
    ),
    timestampHintMs: 1,
  );

  if (request == null) {
    fail('text context request was not issued.');
  }

  return request.request.requestId;
}

// Only context issuance and text guard reads are valid in this fixture; other
// interaction read paths would mean the text guard test crossed owner scope.
// ignore: coupling-between-object-classes, number-of-methods
final class _TextGuardReadPort implements InteractionReadPort {
  _TextGuardReadPort({required this.textGuardFacts});

  final TextCommitGuardReadFacts textGuardFacts;
  int textGuardReads = 0;

  @override
  ContextTargetReadOutcome directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    return AdmittedContextTargetRead(
      ContextTargetReadFacts.contentElement(
        elementId: _textId,
        elementKind: CanvasElementKind.text,
        elementSnapshot: _textElement(),
        boundsWorld: const Rect.fromLTWH(120, 0, 10, 10),
        generation: 1,
        elementRevision: 0,
        family: InteractionElementFamily.text,
        controllerEpoch: 1,
        documentRevision: 0,
      ),
    );
  }

  @override
  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  ) {
    textGuardReads += 1;

    return textGuardFacts;
  }

  @override
  EraserReadFacts eraserPreviewFacts(EraserReadRequest request) {
    throw UnimplementedError('eraser preview is outside this fixture.');
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    throw UnimplementedError('eraser terminal is outside this fixture.');
  }

  @override
  ContextTargetReadOutcome pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    throw UnimplementedError('pending context tap is outside this fixture.');
  }

  @override
  ContextTargetReadOutcome secondContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    throw UnimplementedError('second context tap is outside this fixture.');
  }

  @override
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  ) {
    throw UnimplementedError('selected move is outside this fixture.');
  }

  @override
  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  ) {
    throw UnimplementedError('selected move commit is outside this fixture.');
  }

  @override
  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request) {
    throw UnimplementedError('marquee start is outside this fixture.');
  }

  @override
  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request) {
    throw UnimplementedError('marquee commit is outside this fixture.');
  }
}

CanvasTextElement _textElement() {
  return CanvasTextElement(
    id: _textId,
    text: 'hello',
    color: const Color(0xFF000000),
    textDirection: TextDirection.ltr,
    transform: CanvasTransform.translation(const Offset(120, 0)),
  );
}
