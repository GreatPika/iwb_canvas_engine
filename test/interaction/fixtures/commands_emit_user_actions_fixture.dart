// This integration fixture keeps runtime, commit, and interaction intent seams
// together so action ordering is auditable in one place; splitting imports into
// helper files would hide the cross-seam behavior under test.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';
import '../../support/accept_commit.dart';

void main() {
  test(
    'accepted intents emit actions only after public state',
    () => expectLater(
      _acceptedIntentsEmitActionsOnlyAfterPublicState(),
      completes,
    ),
  );
  test(
    'no-op internal command intents emit no actions',
    () => expectLater(_noOpInternalCommandIntentsEmitNoActions(), completes),
  );
  test(
    'eraser pointer commit emits erase action after state',
    () => expectLater(
      _eraserPointerCommitEmitsEraseActionAfterState(),
      completes,
    ),
  );
  test(
    'empty eraser cleanup emits no action or timestamp',
    () => expectLater(_emptyEraserCleanupEmitsNoActionOrTimestamp(), completes),
  );
  test(
    'eraser edit failure rolls back without action or timestamp',
    () => expectLater(
      _eraserEditFailureRollsBackWithoutActionOrTimestamp(),
      completes,
    ),
  );
}

Future<void> _acceptedIntentsEmitActionsOnlyAfterPublicState() async {
  final result = await _recordAcceptedIntentDelivery();

  expect(result.actions, hasLength(7));
  expect(result.events.first, 'state:1');
  expect(result.events.skip(1), [
    'action:selectMarquee:0',
    'action:moveSelection:3',
    'action:transformSelection:4',
    'action:deleteElements:5',
    'action:deleteElements:6',
    'action:clearContent:7',
    'action:erase:8',
  ]);
  expect(result.actions.map((action) => action.actionId.value), [
    'action-0',
    'action-1',
    'action-2',
    'action-3',
    'action-4',
    'action-5',
    'action-6',
  ]);
}

Future<void> _noOpInternalCommandIntentsEmitNoActions() async {
  final result = await _recordNoOpIntentDelivery();

  expect(result.noOpEvents, isEmpty);
  expect(result.noOpActions, isEmpty);
  expect(result.acceptedAction.timestampMs, 0);
}

Future<void> _eraserPointerCommitEmitsEraseActionAfterState() async {
  final result = await _recordEraserPointerDelivery();

  expect(result.actions, hasLength(1));
  expect(result.events.last, 'action:erase:9');
  expect(
    result.events.where((event) => event.startsWith('state:')),
    isNotEmpty,
  );
  expect(result.lastStateBeforeAction, 'state:2:0');
  expect(result.guardedMutationRejections, 3);
  _expectEraseDeliveryEffects(result.effectBatch);
  _expectEraseAction(result.actions.single);
  expect(result.remainingIds, [CanvasElementId('a'), CanvasElementId('c')]);
}

Future<void> _emptyEraserCleanupEmitsNoActionOrTimestamp() async {
  final result = await _recordEmptyEraserThenAcceptedAction();

  expect(result.emptyActions, isEmpty);
  expect(result.acceptedAction.timestampMs, 0);
}

Future<void> _eraserEditFailureRollsBackWithoutActionOrTimestamp() async {
  final result = await _recordFailedEraserThenAcceptedAction();

  expect(result.failure, isA<StateError>());
  expect(result.actionsAfterFailure, isEmpty);
  expect(result.idsAfterFailure, [
    CanvasElementId('a'),
    CanvasElementId('b'),
    CanvasElementId('c'),
  ]);
  expect(result.acceptedAction.timestampMs, 0);
}

Future<({List<String> events, List<CanvasActionCommitted> actions})>
_recordAcceptedIntentDelivery() async {
  final events = <String>[];
  final actions = <CanvasActionCommitted>[];
  final root = _runtimeRoot(events: events);
  final subscription = root.actions.listen((action) {
    actions.add(action);
    events.add('action:${action.type.name}:${action.timestampMs}');
  });

  try {
    root.deliverCommitPlanForTesting(
      CommitPlan.replaceSelection(
        elementIds: [CanvasElementId('b')],
        actionIntents: _allActionIntents(),
      ),
      document: root.readDocument(),
    );
    await _flushActions();

    return (events: events, actions: actions);
  } finally {
    await _dispose(root, subscription);
  }
}

Future<
  ({
    List<String> noOpEvents,
    List<CanvasActionCommitted> noOpActions,
    CanvasActionCommitted acceptedAction,
  })
>
_recordNoOpIntentDelivery() async {
  final events = <String>[];
  final actions = <CanvasActionCommitted>[];
  final root = _runtimeRoot(events: events);
  final subscription = root.actions.listen(actions.add);

  try {
    root.selection.setSelection([CanvasElementId('a')]);
    events.clear();
    _deliverNoOpMarquee(root);
    await _flushActions();
    final noOpEvents = List<String>.of(events);
    final noOpActions = List<CanvasActionCommitted>.of(actions);

    _deliverAcceptedMarquee(root);
    await _flushActions();

    return (
      noOpEvents: noOpEvents,
      noOpActions: noOpActions,
      acceptedAction: actions.single,
    );
  } finally {
    await _dispose(root, subscription);
  }
}

Future<_EraserPointerDeliveryResult> _recordEraserPointerDelivery() {
  return _EraserPointerDeliveryScenario().run();
}

typedef _EraserPointerDeliveryResult = ({
  List<String> events,
  List<CanvasActionCommitted> actions,
  String lastStateBeforeAction,
  List<CanvasElementId> remainingIds,
  List<CommitDeliveryEffect> effectBatch,
  int guardedMutationRejections,
});

final class _EraserPointerDeliveryScenario {
  _EraserPointerDeliveryScenario() {
    root = _eraserRoot(_observeEffects);
    _recordSummaryStateEvents(root, events, onState: _guardStateMutation);
  }

  late final RuntimeRoot root;
  final List<String> events = [];
  final List<CanvasActionCommitted> actions = [];
  final List<List<CommitDeliveryEffect>> effectBatches = [];
  bool guardDuringDelivery = false;
  int guardedMutationRejections = 0;

  Future<_EraserPointerDeliveryResult> run() async {
    final subscription = root.actions.listen(_recordAction);
    try {
      root.selection.setSelection([CanvasElementId('b')]);
      events.clear();
      guardDuringDelivery = true;
      _performEraserStroke(root);
      guardDuringDelivery = false;
      await _flushActions();

      return _result();
    } finally {
      await subscription.cancel();
      root.dispose();
    }
  }

  void _recordAction(CanvasActionCommitted action) {
    actions.add(action);
    events.add('action:${action.type.name}:${action.timestampMs}');
    guardedMutationRejections += _expectDeliveryGuardedMutation(root);
  }

  void _observeEffects(List<CommitDeliveryEffect> effects) {
    effectBatches.add(effects);
    guardedMutationRejections += _expectDeliveryGuardedMutation(root);
  }

  void _guardStateMutation() {
    if (guardDuringDelivery) {
      guardedMutationRejections += _expectDeliveryGuardedMutation(root);
    }
  }

  _EraserPointerDeliveryResult _result() {
    return (
      events: events,
      actions: actions,
      lastStateBeforeAction: events.lastWhere(
        (event) => event.startsWith('state:'),
      ),
      remainingIds: _contentIds(root.readDocument()),
      effectBatch: effectBatches.single,
      guardedMutationRejections: guardedMutationRejections,
    );
  }
}

Future<
  ({
    List<CanvasActionCommitted> emptyActions,
    CanvasActionCommitted acceptedAction,
  })
>
_recordEmptyEraserThenAcceptedAction() async {
  final root = _eraserRoot();
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);

  try {
    _performEmptyEraserStroke(root);
    await _flushActions();
    final emptyActions = List<CanvasActionCommitted>.of(actions);

    root.selection.setSelection([CanvasElementId('b')]);
    root.deleteSelection();
    await _flushActions();

    return (emptyActions: emptyActions, acceptedAction: actions.single);
  } finally {
    await subscription.cancel();
    root.dispose();
  }
}

Future<
  ({
    Object failure,
    List<CanvasActionCommitted> actionsAfterFailure,
    List<CanvasElementId> idsAfterFailure,
    CanvasActionCommitted acceptedAction,
  })
>
_recordFailedEraserThenAcceptedAction() async {
  final root = _eraserRoot();
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);

  try {
    root.selection.setSelection([CanvasElementId('b')]);
    _performEraserPreview(root);
    final failure = _captureFailure(() {
      root.failEraserCommitPrepareForTesting(
        _eraserCommitIntent(),
        timestampHintMs: 99,
      );
    });
    await _flushActions();
    final actionsAfterFailure = List<CanvasActionCommitted>.of(actions);
    final idsAfterFailure = _contentIds(root.readDocument());

    root.selection.deleteSelection();
    await _flushActions();

    return (
      failure: failure,
      actionsAfterFailure: actionsAfterFailure,
      idsAfterFailure: idsAfterFailure,
      acceptedAction: actions.single,
    );
  } finally {
    await subscription.cancel();
    root.dispose();
  }
}

RuntimeRoot _eraserRoot([
  void Function(List<CommitDeliveryEffect> effects)? observeEffects,
]) {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: acceptCommit,
      initialMode: CanvasInteractionMode.draw,
      initialDrawStyle: CanvasDrawStyle(
        tool: CanvasDrawTool.eraser,
        eraserThickness: 8,
      ),
    ),
    commitEffectObserver: observeEffects,
  );
}

void _recordSummaryStateEvents(
  RuntimeRoot root,
  List<String> events, {
  void Function()? onState,
}) {
  root.state.addListener(() {
    final state = root.state.value;
    events.add(
      'state:${state.summary.elementCount}:${state.summary.selectedCount}',
    );
    onState?.call();
  });
}

void _performEraserStroke(RuntimeRoot root) {
  _performEraserPreview(root);
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(22, 0), 9),
  );
}

void _performEraserPreview(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(20, 0)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(21, 0)),
  );
}

void _performEmptyEraserStroke(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(200, 200), 99),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(201, 200), 100),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(202, 200), 101),
  );
}

RuntimeRoot _runtimeRoot({required List<String> events}) {
  final root = runtimeRootWithCommittedDocumentSeed(_document());
  root.state.addListener(() {
    events.add('state:${root.state.value.revisions.selection}');
  });

  return root;
}

void _deliverNoOpMarquee(RuntimeRoot root) {
  root.deliverCommitPlanForTesting(
    CommitPlan.replaceSelection(
      elementIds: [CanvasElementId('a')],
      actionIntents: [
        SelectMarqueeActionIntent(
          previousSelection: [CanvasElementId('a')],
          nextSelection: [CanvasElementId('a')],
          marqueeRectWorld: const Rect.fromLTRB(0, 0, 1, 1),
          timestampHintMs: 99,
        ),
      ],
    ),
    document: root.readDocument(),
  );
}

void _deliverAcceptedMarquee(RuntimeRoot root) {
  root.deliverCommitPlanForTesting(
    CommitPlan.replaceSelection(
      elementIds: [CanvasElementId('b')],
      actionIntents: [
        SelectMarqueeActionIntent(
          previousSelection: [CanvasElementId('a')],
          nextSelection: [CanvasElementId('b')],
          marqueeRectWorld: const Rect.fromLTRB(0, 0, 1, 1),
        ),
      ],
    ),
    document: root.readDocument(),
  );
}

List<CommitActionIntent> _allActionIntents() {
  return [..._legacyActionIntents(), _eraseIntent()];
}

List<CommitActionIntent> _legacyActionIntents() {
  return [
    SelectMarqueeActionIntent(
      previousSelection: [CanvasElementId('a')],
      nextSelection: [CanvasElementId('b')],
      marqueeRectWorld: const Rect.fromLTRB(0, 0, 10, 10),
    ),
    MoveSelectionActionIntent(
      elementIds: [CanvasElementId('b')],
      transform: CanvasTransform.translation(const Offset(1, 2)),
      timestampHintMs: 3,
    ),
    TransformSelectionActionIntent(
      elementIds: [CanvasElementId('b')],
      transform: CanvasTransform.rotationDegrees(90),
      operation: CanvasTransformOperation.rotateClockwise,
      pivotWorld: const Offset(5, 6),
      timestampHintMs: 1,
    ),
    DeleteSelectionActionIntent(
      removedElementIds: [CanvasElementId('b')],
      timestampHintMs: 4,
    ),
    RemoveElementActionIntent(
      elementId: CanvasElementId('c'),
      timestampHintMs: 4,
    ),
    ClearContentActionIntent(
      removedElementIds: [CanvasElementId('b'), CanvasElementId('c')],
      removedResourceIds: [CanvasResourceId('r1')],
      timestampHintMs: 2,
    ),
  ];
}

CommitActionIntent _eraseIntent() {
  return EraseActionIntent(
    erasedElementIds: [CanvasElementId('b')],
    eraserThickness: 8,
    corridorPointCount: 3,
    timestampHintMs: 6,
  );
}

Future<void> _dispose(
  RuntimeRoot root,
  StreamSubscription<CanvasActionCommitted> subscription,
) async {
  await subscription.cancel();
  root.dispose();
}

Future<void> _flushActions() => Future<void>.delayed(Duration.zero);

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

void _expectEraseAction(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.erase);
  expect(action.elementIds, [CanvasElementId('b')]);
  final payload = action.payload as CanvasEraseActionPayload;
  expect(payload.erasedElementIds, [CanvasElementId('b')]);
  expect(payload.eraserThickness, 8);
  expect(payload.corridorPointCount, 3);
}

void _expectEraseDeliveryEffects(List<CommitDeliveryEffect> effects) {
  expect(effects.whereType<ProjectionDeliveryEffect>(), hasLength(1));
  expect(effects.whereType<SpatialDeliveryEffect>(), hasLength(1));
  final repaint = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isTrue);
}

int _expectDeliveryGuardedMutation(RuntimeRoot root) {
  expect(root.selection.clearSelection, throwsStateError);

  return 1;
}

Object _captureFailure(void Function() action) {
  try {
    action();
  } on Object catch (error) {
    return error;
  }

  fail('expected action to throw');
}

EraserCommitIntent _eraserCommitIntent() {
  return EraserCommitIntent(
    sessionId: const PointerSessionId(1),
    pointerToken: const PointerSessionToken(1),
    eraserThickness: 8,
    corridorWorld: const [Offset.zero, Offset(1, 0), Offset(2, 0)],
    erasedEntries: [
      DeletionEntryFacts(
        element: CanvasRectElement(
          id: CanvasElementId('b'),
          size: const Size(1, 1),
        ),
        layerId: CanvasLayerId('fixture-layer'),
        elementIndex: 0,
        orderToken: 0,
      ),
    ],
  );
}

List<CanvasElementId> _contentIds(CanvasDocument document) {
  return [
    for (final layer in document.layers)
      for (final element in layer.elements) element.id,
  ];
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('r1'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(1, 1)),
          CanvasRectElement(
            id: CanvasElementId('b'),
            size: const Size(1, 1),
            transform: CanvasTransform.translation(const Offset(20, 0)),
          ),
          CanvasImageElement(
            id: CanvasElementId('c'),
            resourceId: CanvasResourceId('r1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
