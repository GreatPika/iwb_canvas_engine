// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';
import '../../support/runtime_with_document.dart';
import '../../support/accept_deletion_commit.dart';

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
    'public selection and command ports emit payload families',
    _publicSelectionAndCommandPortsEmitPayloadFamilies,
  );

  test(
    'commit text edit emits payload without raw text and ignores no-op timestamps',
    _commitTextEditEmitsPayloadWithoutRawTextAndIgnoresNoOpTimestamps,
  );
}

Future<void> _runtimeActionFinalizerPreservesPublicActionPayloadMatrix() async {
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: acceptDeletionCommit,
      pointerPolicy: CanvasPointerPolicy(tapSlop: 1),
    ),
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
    document: root.readDocument(),
  );
  await Future<void>.delayed(Duration.zero);

  expect(actions, hasLength(10));
  expect(
    actions.map((action) => action.timestampMs),
    List.generate(10, (index) => index),
  );
  _expectLegacyActionPayloads(actions);
  _expectDrawActionPayloads(actions);
  _expectErase(actions[9]);
}

void _expectLegacyActionPayloads(List<CanvasActionCommitted> actions) {
  _expectMarquee(actions[0]);
  _expectMove(actions[1]);
  _expectTransform(actions[2]);
  _expectDeleteSelection(actions[3]);
  _expectRemoveElement(actions[4]);
  _expectClearContent(actions[5]);
}

void _expectDrawActionPayloads(List<CanvasActionCommitted> actions) {
  _expectPencilStroke(actions[6]);
  _expectMarkerStroke(actions[7]);
  _expectLine(actions[8]);
}

Future<void> _selectedMoveTerminalEmitsPublicMovePayloadShape() async {
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: acceptDeletionCommit,
      pointerPolicy: CanvasPointerPolicy(tapSlop: 1),
    ),
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
  final root = runtimeRootWithCommittedDocumentSeed(_document());
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });
  root.selection.setSelection([CanvasElementId('a')]);

  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(18, -20)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(23, 3)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(23, 3)),
  );
  await Future<void>.delayed(Duration.zero);

  expect(actions, hasLength(1));
  _expectMarquee(
    actions.single,
    marqueeRectWorld: const Rect.fromLTRB(18, -20, 23, 3),
  );
}

Future<void> _publicSelectionAndCommandPortsEmitPayloadFamilies() async {
  await _expectPublicMoveAction();
  await _expectPublicRotateAction();
  await _expectPublicFlipAction();
  await _expectPublicDeleteAction();
  await _expectSinglePublicAction((runtime) {
    runtime.commands.removeElement(CanvasElementId('c'));
  }, _expectRemoveElement);
  await _expectPublicClearAction();
}

Future<void>
_commitTextEditEmitsPayloadWithoutRawTextAndIgnoresNoOpTimestamps() async {
  final runtime = runtimeWithDocument(_documentWithText());
  final actions = <CanvasActionCommitted>[];
  final requests = <CanvasContextActionRequested>[];
  final actionSubscription = runtime.actions.listen(actions.add);
  final requestSubscription = runtime.contextActionRequests.listen(
    requests.add,
  );
  try {
    await _expectNoOpTimestampIgnored(runtime, actions, requests);
    await _expectStaleTimestampIgnored(runtime, actions, requests);
    await _expectChangedCommitPayload(runtime, actions, requests);
  } finally {
    await actionSubscription.cancel();
    await requestSubscription.cancel();
    runtime.dispose();
  }
}

Future<void> _expectNoOpTimestampIgnored(
  CanvasRuntime runtime,
  List<CanvasActionCommitted> actions,
  List<CanvasContextActionRequested> requests,
) async {
  final requestId = await _requestTextEdit(runtime, requests);
  expect(
    runtime.commands.commitTextEdit(requestId, 'hello', timestampMs: 99),
    isTrue,
  );
  expect(actions, isEmpty);
}

Future<void> _expectStaleTimestampIgnored(
  CanvasRuntime runtime,
  List<CanvasActionCommitted> actions,
  List<CanvasContextActionRequested> requests,
) async {
  final requestId = await _requestTextEdit(runtime, requests);
  runtime.edits.edit(
    (edit) => edit.updateElement(
      CanvasTextElementUpdate(id: _textId, fontSize: const CanvasFieldSet(30)),
    ),
  );

  expect(
    runtime.commands.commitTextEdit(requestId, 'ignored', timestampMs: 100),
    isFalse,
  );
  expect(actions, isEmpty);
}

Future<void> _expectChangedCommitPayload(
  CanvasRuntime runtime,
  List<CanvasActionCommitted> actions,
  List<CanvasContextActionRequested> requests,
) async {
  final requestId = await _requestTextEdit(runtime, requests);
  expect(runtime.commands.commitTextEdit(requestId, 'updated'), isTrue);
  await Future<void>.delayed(Duration.zero);

  expect(actions, hasLength(1));
  expect(actions.single.timestampMs, 3);
  expect(actions.single.type, CanvasActionType.editText);
  expect(actions.single.elementIds, [_textId]);
  final payload = actions.single.payload as CanvasTextEditActionPayload;
  expect(payload.requestId, requestId);
  expect(payload.previousTextLength, 5);
  expect(payload.nextTextLength, 7);
}

Future<CanvasInteractionRequestId> _requestTextEdit(
  CanvasRuntime runtime,
  List<CanvasContextActionRequested> requests,
) async {
  runtime.tools.handleDoubleTap(position: const Offset(120, 0));
  await Future<void>.delayed(Duration.zero);
  final requestId = requests.single.requestId;
  requests.clear();

  return requestId;
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
  final runtime = runtimeWithDocument(_document());
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
  return [..._legacyActionIntents(), ..._drawActionIntents(), _eraseIntent()];
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

List<CommitActionIntent> _drawActionIntents() {
  return [
    DrawStrokeActionIntent(
      elementId: CanvasElementId('stroke-pencil'),
      tool: CanvasDrawTool.pencil,
      color: const Color(0xFF112233),
      thickness: 3,
      opacity: 1,
      pointCount: 2,
    ),
    DrawStrokeActionIntent(
      elementId: CanvasElementId('stroke-marker'),
      tool: CanvasDrawTool.marker,
      color: const Color(0xFF445566),
      thickness: 12,
      opacity: 0.4,
      pointCount: 3,
    ),
    DrawLineActionIntent(
      elementId: CanvasElementId('line-1'),
      color: const Color(0xFF778899),
      thickness: 4,
      opacity: 1,
      startWorld: const Offset(1, 2),
      endWorld: const Offset(3, 4),
    ),
  ];
}

CommitActionIntent _eraseIntent() {
  return EraseActionIntent(
    erasedElementIds: [CanvasElementId('b'), CanvasElementId('c')],
    eraserThickness: 8,
    corridorPointCount: 3,
  );
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

void _expectPencilStroke(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawPencil);
  expect(action.elementIds, [CanvasElementId('stroke-pencil')]);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.pencil);
  expect(payload.color, const Color(0xFF112233));
  expect(payload.thickness, 3);
  expect(payload.opacity, 1);
  expect(payload.pointCount, 2);
}

void _expectMarkerStroke(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawMarker);
  expect(action.elementIds, [CanvasElementId('stroke-marker')]);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.marker);
  expect(payload.color, const Color(0xFF445566));
  expect(payload.thickness, 12);
  expect(payload.opacity, 0.4);
  expect(payload.pointCount, 3);
}

void _expectLine(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawLine);
  expect(action.elementIds, [CanvasElementId('line-1')]);
  final payload = action.payload as CanvasDrawLineActionPayload;
  expect(payload.color, const Color(0xFF778899));
  expect(payload.thickness, 4);
  expect(payload.opacity, 1);
  expect(payload.startWorld, const Offset(1, 2));
  expect(payload.endWorld, const Offset(3, 4));
}

void _expectErase(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.erase);
  expect(action.elementIds, [CanvasElementId('b'), CanvasElementId('c')]);
  final payload = action.payload as CanvasEraseActionPayload;
  expect(payload.erasedElementIds, action.elementIds);
  expect(payload.eraserThickness, 8);
  expect(payload.corridorPointCount, 3);
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

CanvasDocument _documentWithText() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
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

final CanvasElementId _textId = CanvasElementId('text-a');
