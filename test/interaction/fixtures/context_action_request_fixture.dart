import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('direct content double tap emits one content request', () {
    return expectLater(_verifyDirectContentRequest(), completes);
  });
  test('direct content double tap uses context hit bounds', () {
    return expectLater(_verifyPaddedContextHitRequest(), completes);
  });
  test('direct empty double tap emits one empty request', () {
    return expectLater(_verifyDirectEmptyRequest(), completes);
  });
  test('non-finite direct double tap is rejected before timestamp', () {
    return expectLater(
      _verifyNonFiniteDirectRejectsBeforeTimestamp(),
      completes,
    );
  });
  test('pointer sample down-up double tap emits one request', () {
    return expectLater(_verifyPointerSampleDoubleTapRequest(), completes);
  });
  test('pointer sample double tap works on selected content', () {
    return expectLater(_verifySelectedContentPointerRequest(), completes);
  });
  test('pointer sample mismatch clears without public effects', () {
    return expectLater(_verifyPointerSampleMismatchIsPrivate(), completes);
  });
  test('pointer tap movement inside tap slop stays private', () {
    return expectLater(_verifyPointerTapInsideTapSlopIsPrivate(), completes);
  });
  test('private pointer tap does not leak through later state', () {
    return expectLater(_verifyPrivateTapRevisionStaysPrivate(), completes);
  });
}

Future<void> _verifyDirectContentRequest() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(
      position: const Offset(20, 0),
      timestampMs: 7,
    );
    await _flushEvents();

    _expectNoIncidentalEffects(scenario);
    _expectContentRequest(scenario.requests.single);
  } finally {
    await scenario.dispose();
  }
}

void _expectNoIncidentalEffects(_RuntimeContextRequestScenario scenario) {
  expect(scenario.stateEvents, isEmpty);
  expect(scenario.actions, isEmpty);
  expect(scenario.effectBatches, isEmpty);
}

void _expectContentRequest(
  CanvasContextActionRequested request, {
  Offset position = const Offset(20, 0),
}) {
  expect(request.trigger, CanvasContextActionTrigger.doubleTap);
  expect(request.timestampMs, 7);
  expect(request.viewPosition, position);
  expect(request.worldPosition, position);
  expect(request.controllerEpoch, 0);
  expect(request.documentRevision, 0);
  final target = request.target as CanvasContentElementContextActionTarget;
  expect(target.elementSnapshot.id, CanvasElementId('rect-a'));
  expect(target.boundsWorld.left, 15);
}

Future<void> _verifyDirectEmptyRequest() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(position: const Offset(200, 200));
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    expect(
      scenario.requests.single.target,
      isA<CanvasEmptyCanvasContextActionTarget>(),
    );
    _expectNoIncidentalEffects(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPaddedContextHitRequest() async {
  final scenario = _RuntimeContextRequestScenario(hitPadding: 4);
  try {
    scenario.root.handleDoubleTap(
      position: const Offset(12, 0),
      timestampMs: 7,
    );
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    _expectContentRequest(
      scenario.requests.single,
      position: const Offset(12, 0),
    );
    _expectNoIncidentalEffects(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyNonFiniteDirectRejectsBeforeTimestamp() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(position: const Offset(double.nan, 1));
    scenario.root.handleDoubleTap(position: const Offset(200, 200));
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    expect(scenario.requests.single.timestampMs, 0);
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPointerSampleDoubleTapRequest() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(21, 0), timestampMs: 2);
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    final request = scenario.requests.single;
    expect(request.timestampMs, 2);
    expect(request.target, isA<CanvasContentElementContextActionTarget>());
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifySelectedContentPointerRequest() async {
  final scenario = _RuntimeContextRequestScenario(selectableContent: true);
  try {
    scenario.root.selection.setSelection([CanvasElementId('rect-a')]);
    scenario.stateEvents.clear();

    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(21, 0), timestampMs: 2);
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    expect(
      scenario.requests.single.target,
      isA<CanvasContentElementContextActionTarget>(),
    );
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPointerSampleMismatchIsPrivate() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(200, 200), timestampMs: 2);
    await _flushEvents();

    expect(scenario.requests, isEmpty);
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPointerTapInsideTapSlopIsPrivate() async {
  final scenario = _RuntimeContextRequestScenario(
    config: CanvasRuntimeConfig(
      pointerPolicy: CanvasPointerPolicy(tapSlop: 8, dragStartSlop: 4),
    ),
  );
  try {
    _tapPointer(
      scenario.root,
      const Offset(200, 200),
      movePosition: const Offset(205, 200),
      timestampMs: 1,
    );
    await _flushEvents();

    expect(scenario.requests, isEmpty);
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.root.preview, isA<CanvasNoPreview>());
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPrivateTapRevisionStaysPrivate() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    _tapPointer(scenario.root, const Offset(200, 200), timestampMs: 1);
    final interactionRevision = scenario.root.state.value.revisions.interaction;
    scenario.root.panCameraBy(const Offset(1, 0));
    await _flushEvents();

    expect(scenario.requests, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
    expect(scenario.stateEvents, hasLength(1));
    expect(scenario.stateEvents.single.revisions.viewCamera, 1);
    expect(
      scenario.stateEvents.single.revisions.interaction,
      interactionRevision,
    );
  } finally {
    await scenario.dispose();
  }
}

final class _RuntimeContextRequestScenario {
  _RuntimeContextRequestScenario({
    bool selectableContent = false,
    double hitPadding = 0,
    CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
  }) {
    root = RuntimeRoot(
      initialDocument: _document(
        selectableContent: selectableContent,
        hitPadding: hitPadding,
      ),
      config: config,
      commitEffectObserver: effectBatches.add,
    );
    root.state.addListener(() {
      stateEvents.add(root.state.value);
    });
    requestSubscription = root.contextActionRequests.listen(requests.add);
    actionSubscription = root.actions.listen(actions.add);
  }

  late final RuntimeRoot root;
  late final StreamSubscription<CanvasContextActionRequested>
  requestSubscription;
  late final StreamSubscription<CanvasActionCommitted> actionSubscription;
  final List<CanvasContextActionRequested> requests = [];
  final List<CanvasActionCommitted> actions = [];
  final List<CanvasRuntimeState> stateEvents = [];
  final List<List<CommitDeliveryEffect>> effectBatches = [];

  Future<void> dispose() async {
    await requestSubscription.cancel();
    await actionSubscription.cancel();
    root.dispose();
  }
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

void _tapPointer(
  RuntimeRoot root,
  Offset position, {
  required int timestampMs,
  Offset? movePosition,
}) {
  root.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: position,
      phase: CanvasPointerLifecyclePhase.down,
      kind: PointerDeviceKind.touch,
      timestampMs: timestampMs,
    ),
  );
  final moved = movePosition;
  if (moved != null) {
    root.handlePointer(
      CanvasPointerSample(
        pointerId: 1,
        position: moved,
        phase: CanvasPointerLifecyclePhase.move,
        kind: PointerDeviceKind.touch,
        timestampMs: timestampMs,
      ),
    );
  }
  root.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: movePosition ?? position,
      phase: CanvasPointerLifecyclePhase.up,
      kind: PointerDeviceKind.touch,
      timestampMs: timestampMs,
    ),
  );
}

CanvasDocument _document({
  required bool selectableContent,
  required double hitPadding,
}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
            isSelectable: selectableContent,
            hitPadding: hitPadding,
          ),
        ],
      ),
    ],
  );
}
