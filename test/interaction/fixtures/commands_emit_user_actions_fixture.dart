import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('accepted intents emit actions only after public state', () async {
    final result = await _recordAcceptedIntentDelivery();

    expect(result.actions, hasLength(6));
    expect(result.events.first, 'state:1');
    expect(result.events.skip(1), [
      'action:selectMarquee:0',
      'action:moveSelection:3',
      'action:transformSelection:4',
      'action:deleteElements:5',
      'action:deleteElements:6',
      'action:clearContent:7',
    ]);
    expect(result.actions.map((action) => action.actionId.value), [
      'action-0',
      'action-1',
      'action-2',
      'action-3',
      'action-4',
      'action-5',
    ]);
  });

  test('no-op internal command intents emit no actions', () async {
    final result = await _recordNoOpIntentDelivery();

    expect(result.noOpEvents, isEmpty);
    expect(result.noOpActions, isEmpty);
    expect(result.acceptedAction.timestampMs, 0);
  });
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

RuntimeRoot _runtimeRoot({required List<String> events}) {
  final root = RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
  );
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
  );
}

List<CommitActionIntent> _allActionIntents() {
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

Future<void> _dispose(
  RuntimeRoot root,
  StreamSubscription<CanvasActionCommitted> subscription,
) async {
  await subscription.cancel();
  root.dispose();
}

Future<void> _flushActions() => Future<void>.delayed(Duration.zero);

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
          CanvasRectElement(id: CanvasElementId('b'), size: const Size(1, 1)),
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
