import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('typed action payloads expose their public fields', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_typed_action_payloads_consumer',
        testFileName: 'typed_action_payloads_test.dart',
        testSource: _typedActionPayloadsSource,
      ),
      completes,
    );
  });
}

const _typedActionPayloadsSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('typed action payloads expose their public fields', () {
    final elementId = CanvasElementId('element-1');
    final nextElementId = CanvasElementId('element-2');
    final resourceId = CanvasResourceId('resource-1');
    final requestId = CanvasInteractionRequestId('request-1');
    final transform = CanvasTransform.translation(const Offset(1, 2));

    final payloads = <CanvasActionPayload>[
      CanvasTransformActionPayload(
        delta: transform,
        operation: CanvasTransformOperation.move,
        pivotWorld: const Offset(3, 4),
      ),
      CanvasSelectionActionPayload(
        previousSelection: [elementId],
        nextSelection: [nextElementId],
        marqueeRectWorld: const Rect.fromLTWH(0, 0, 10, 10),
      ),
      CanvasDeleteActionPayload(removedElementIds: [elementId]),
      CanvasClearActionPayload(
        removedElementIds: [elementId],
        removedResourceIds: [resourceId],
      ),
      const CanvasDrawStrokeActionPayload(
        tool: CanvasDrawTool.marker,
        color: Color(0xFF000000),
        thickness: 4,
        opacity: 0.5,
        pointCount: 2,
      ),
      const CanvasDrawLineActionPayload(
        color: Color(0xFF000000),
        thickness: 2,
        opacity: 1,
        startWorld: Offset.zero,
        endWorld: Offset(1, 1),
      ),
      CanvasEraseActionPayload(
        eraserThickness: 8,
        erasedElementIds: [elementId],
        corridorPointCount: 3,
      ),
      CanvasTextEditActionPayload(
        requestId: requestId,
        previousTextLength: 1,
        nextTextLength: 2,
      ),
    ];

    expect(payloads, everyElement(isA<CanvasActionPayload>()));
    expect(
      payloads.whereType<CanvasTransformActionPayload>().single.delta,
      transform,
    );
    expect(
      payloads.whereType<CanvasSelectionActionPayload>().single.nextSelection,
      [nextElementId],
    );
    expect(
      payloads.whereType<CanvasDeleteActionPayload>().single.removedElementIds,
      [elementId],
    );
    expect(
      payloads.whereType<CanvasClearActionPayload>().single.removedResourceIds,
      [resourceId],
    );
    expect(
      payloads.whereType<CanvasDrawStrokeActionPayload>().single.tool,
      CanvasDrawTool.marker,
    );
    expect(
      payloads.whereType<CanvasDrawLineActionPayload>().single.endWorld,
      const Offset(1, 1),
    );
    expect(
      payloads.whereType<CanvasEraseActionPayload>().single.erasedElementIds,
      [elementId],
    );
    expect(
      payloads.whereType<CanvasTextEditActionPayload>().single.requestId,
      requestId,
    );
  });

  test('action and context request carry typed payloads and targets', () {
    final element = CanvasRectElement(
      id: CanvasElementId('element-1'),
      size: const Size(1, 1),
    );
    final action = CanvasActionCommitted(
      actionId: CanvasActionId('action-1'),
      type: CanvasActionType.transformSelection,
      elementIds: [element.id],
      timestampMs: 10,
      payload: CanvasTransformActionPayload(
        delta: CanvasTransform.identity,
        operation: CanvasTransformOperation.rotateClockwise,
      ),
    );
    final request = CanvasContextActionRequested(
      requestId: CanvasInteractionRequestId('request-1'),
      trigger: CanvasContextActionTrigger.doubleTap,
      target: CanvasContentElementContextActionTarget(
        elementSnapshot: element,
        boundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
      ),
      controllerEpoch: 1,
      documentRevision: 2,
      timestampMs: 3,
      viewPosition: const Offset(4, 5),
      worldPosition: const Offset(6, 7),
    );

    expect(action.payload, isA<CanvasTransformActionPayload>());
    expect(action.elementIds, [element.id]);
    expect(request.target, isA<CanvasContentElementContextActionTarget>());
    expect(
      const CanvasEmptyCanvasContextActionTarget(),
      isA<CanvasContextActionTarget>(),
    );
  });
}
''';
