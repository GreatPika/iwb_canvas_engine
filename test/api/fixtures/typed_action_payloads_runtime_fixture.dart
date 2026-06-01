import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test(
    'runtime action finalizer preserves public action payload matrix',
    () async {
      final root = RuntimeRoot(
        initialDocument: _document(),
        config: const CanvasRuntimeConfig(),
      );
      final actions = <CanvasActionCommitted>[];
      final subscription = root.actions.listen(actions.add);
      addTearDown(() async {
        await subscription.cancel();
        root.dispose();
      });

      root.deliverCommitPlanForTesting(
        CommitPlan.replaceSelection(
          elementIds: [CanvasElementId('b')],
          actionIntents: _actionIntents(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(actions, hasLength(6));
      _expectMarquee(actions[0]);
      _expectMove(actions[1]);
      _expectTransform(actions[2]);
      _expectDeleteSelection(actions[3]);
      _expectRemoveElement(actions[4]);
      _expectClearContent(actions[5]);
    },
  );
}

List<CommitActionIntent> _actionIntents() {
  return [
    SelectMarqueeActionIntent(
      previousSelection: [CanvasElementId('a')],
      nextSelection: [CanvasElementId('b')],
      marqueeRectWorld: const Rect.fromLTRB(0, 0, 10, 10),
    ),
    MoveSelectionActionIntent(
      elementIds: [CanvasElementId('b')],
      transform: CanvasTransform.translation(const Offset(2, 3)),
    ),
    TransformSelectionActionIntent(
      elementIds: [CanvasElementId('b')],
      transform: CanvasTransform.rotationDegrees(90),
      operation: CanvasTransformOperation.rotateClockwise,
      pivotWorld: const Offset(4, 5),
    ),
    DeleteSelectionActionIntent(
      removedElementIds: [CanvasElementId('b'), CanvasElementId('c')],
    ),
    RemoveElementActionIntent(elementId: CanvasElementId('c')),
    ClearContentActionIntent(
      removedElementIds: [CanvasElementId('b'), CanvasElementId('c')],
      removedResourceIds: [CanvasResourceId('r1')],
    ),
  ];
}

void _expectMarquee(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.selectMarquee);
  expect(action.elementIds, [CanvasElementId('b')]);
  final payload = action.payload as CanvasSelectionActionPayload;
  expect(payload.previousSelection, [CanvasElementId('a')]);
  expect(payload.nextSelection, [CanvasElementId('b')]);
  expect(payload.marqueeRectWorld, const Rect.fromLTRB(0, 0, 10, 10));
}

void _expectMove(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.moveSelection);
  expect(action.elementIds, [CanvasElementId('b')]);
  final payload = action.payload as CanvasTransformActionPayload;
  expect(payload.delta, CanvasTransform.translation(const Offset(2, 3)));
  expect(payload.operation, CanvasTransformOperation.move);
  expect(payload.pivotWorld, isNull);
}

void _expectTransform(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.transformSelection);
  expect(action.elementIds, [CanvasElementId('b')]);
  final payload = action.payload as CanvasTransformActionPayload;
  expect(payload.delta, CanvasTransform.rotationDegrees(90));
  expect(payload.operation, CanvasTransformOperation.rotateClockwise);
  expect(payload.pivotWorld, const Offset(4, 5));
}

void _expectDeleteSelection(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.deleteElements);
  expect(action.elementIds, [CanvasElementId('b'), CanvasElementId('c')]);
  final payload = action.payload as CanvasDeleteActionPayload;
  expect(payload.removedElementIds, [
    CanvasElementId('b'),
    CanvasElementId('c'),
  ]);
}

void _expectRemoveElement(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.deleteElements);
  expect(action.elementIds, [CanvasElementId('c')]);
  final payload = action.payload as CanvasDeleteActionPayload;
  expect(payload.removedElementIds, [CanvasElementId('c')]);
}

void _expectClearContent(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.clearContent);
  expect(action.elementIds, [CanvasElementId('b'), CanvasElementId('c')]);
  final payload = action.payload as CanvasClearActionPayload;
  expect(payload.removedElementIds, [
    CanvasElementId('b'),
    CanvasElementId('c'),
  ]);
  expect(payload.removedResourceIds, [CanvasResourceId('r1')]);
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
