// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test(
    'runtime action finalizer preserves public action payload matrix',
    _runtimeActionFinalizerPreservesPublicActionPayloadMatrix,
  );

  test(
    'selected move terminal emits the public move payload shape',
    _selectedMoveTerminalEmitsPublicMovePayloadShape,
  );

  test(
    'marquee terminal emits the public selection payload shape',
    _marqueeTerminalEmitsPublicSelectionPayloadShape,
  );

  test(
    'public selection and command ports emit P10 payload families',
    _publicSelectionAndCommandPortsEmitP10PayloadFamilies,
  );
}

Future<void> _runtimeActionFinalizerPreservesPublicActionPayloadMatrix() async {
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
}

Future<void> _selectedMoveTerminalEmitsPublicMovePayloadShape() async {
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
  root.selection.setSelection([CanvasElementId('b')]);

  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(20, 0)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(22, 3)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(22, 3)),
  );
  await Future<void>.delayed(Duration.zero);

  expect(actions, hasLength(1));
  _expectMove(actions.single);
}

// The pointer sequence and resulting payload assertion stay together to prove
// the terminal marquee action shape from one runtime interaction.
// ignore: halstead-volume
Future<void> _marqueeTerminalEmitsPublicSelectionPayloadShape() async {
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
  root.selection.setSelection([CanvasElementId('a')]);

  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(19, -1)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(22, 2)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(22, 2)),
  );
  await Future<void>.delayed(Duration.zero);

  expect(actions, hasLength(1));
  _expectMarquee(
    actions.single,
    marqueeRectWorld: const Rect.fromLTRB(19, -1, 22, 2),
  );
}

Future<void> _publicSelectionAndCommandPortsEmitP10PayloadFamilies() async {
  await _expectPublicMoveAction();
  await _expectPublicRotateAction();
  await _expectPublicFlipAction();
  await _expectPublicDeleteAction();
  await _expectSinglePublicAction((runtime) {
    runtime.commands.removeElement(CanvasElementId('c'));
  }, _expectRemoveElement);
  await _expectPublicClearAction();
}

Future<void> _expectPublicMoveAction() {
  return _expectSinglePublicAction((runtime) {
    runtime.selection.setSelection([CanvasElementId('b')]);
    runtime.selection.moveSelection(const Offset(2, 3));
  }, _expectMove);
}

Future<void> _expectPublicRotateAction() {
  return _expectSinglePublicAction(
    (runtime) {
      runtime.selection.setSelection([CanvasElementId('b')]);
      runtime.selection.rotateSelectionClockwise();
    },
    (action) => _expectPublicTransformOperation(
      action,
      CanvasTransformOperation.rotateClockwise,
    ),
  );
}

Future<void> _expectPublicFlipAction() {
  return _expectSinglePublicAction(
    (runtime) {
      runtime.selection.setSelection([CanvasElementId('b')]);
      runtime.selection.flipSelectionVertical();
    },
    (action) => _expectPublicTransformOperation(
      action,
      CanvasTransformOperation.flipVertical,
    ),
  );
}

Future<void> _expectPublicDeleteAction() {
  return _expectSinglePublicAction(
    (runtime) {
      runtime.selection.setSelection([CanvasElementId('b')]);
      runtime.selection.deleteSelection();
    },
    (action) {
      expect(action.type, CanvasActionType.deleteElements);
      expect(action.elementIds, [CanvasElementId('b')]);
      final payload = action.payload as CanvasDeleteActionPayload;
      expect(payload.removedElementIds, [CanvasElementId('b')]);
    },
  );
}

Future<void> _expectPublicClearAction() {
  return _expectSinglePublicAction(
    (runtime) {
      runtime.commands.clearContent(removeUnusedResources: true);
    },
    (action) {
      expect(action.type, CanvasActionType.clearContent);
      expect(action.elementIds, [
        CanvasElementId('a'),
        CanvasElementId('b'),
        CanvasElementId('c'),
      ]);
      final payload = action.payload as CanvasClearActionPayload;
      expect(payload.removedElementIds, action.elementIds);
      expect(payload.removedResourceIds, [CanvasResourceId('r1')]);
    },
  );
}

void _expectPublicTransformOperation(
  CanvasActionCommitted action,
  CanvasTransformOperation operation,
) {
  expect(action.type, CanvasActionType.transformSelection);
  expect(action.elementIds, [CanvasElementId('b')]);
  final payload = action.payload as CanvasTransformActionPayload;
  expect(payload.operation, operation);
  expect(payload.pivotWorld, isNotNull);
}

Future<void> _expectSinglePublicAction(
  void Function(CanvasRuntime runtime) mutate,
  void Function(CanvasActionCommitted action) expectAction,
) async {
  final runtime = CanvasRuntime(initialDocument: _document());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  try {
    mutate(runtime);
    await Future<void>.delayed(Duration.zero);
    expect(actions, hasLength(1));
    expectAction(actions.single);
  } finally {
    await subscription.cancel();
    runtime.dispose();
  }
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

void _expectMarquee(
  CanvasActionCommitted action, {
  Rect marqueeRectWorld = const Rect.fromLTRB(0, 0, 10, 10),
}) {
  expect(action.type, CanvasActionType.selectMarquee);
  expect(action.elementIds, [CanvasElementId('b')]);
  final payload = action.payload as CanvasSelectionActionPayload;
  expect(payload.previousSelection, [CanvasElementId('a')]);
  expect(payload.nextSelection, [CanvasElementId('b')]);
  expect(payload.marqueeRectWorld, marqueeRectWorld);
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
