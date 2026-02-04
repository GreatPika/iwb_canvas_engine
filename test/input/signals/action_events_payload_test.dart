import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  test('tryMoveLayerIndices parses move payload', () {
    final event = ActionCommitted(
      actionId: 'a0',
      type: ActionType.move,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{
        'sourceLayerIndex': 1,
        'targetLayerIndex': 3,
      },
    );

    expect(event.tryMoveLayerIndices(), (
      sourceLayerIndex: 1,
      targetLayerIndex: 3,
    ));
  });

  test('tryDrawStyle parses draw payload', () {
    final event = ActionCommitted(
      actionId: 'a1',
      type: ActionType.drawStroke,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{
        'tool': 'pen',
        'color': 0xFF000000,
        'thickness': 3,
      },
    );

    expect(event.tryDrawStyle(), (
      tool: 'pen',
      colorArgb: 0xFF000000,
      thickness: 3.0,
    ));
  });

  test('tryEraserThickness parses erase payload', () {
    final event = ActionCommitted(
      actionId: 'a2',
      type: ActionType.erase,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{'eraserThickness': 12},
    );

    expect(event.tryEraserThickness(), 12.0);
  });

  test('payload accessors return null for invalid payloads', () {
    final event = ActionCommitted(
      actionId: 'a3',
      type: ActionType.move,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{'sourceLayerIndex': 'nope'},
    );

    expect(event.tryMoveLayerIndices(), isNull);
    expect(event.tryDrawStyle(), isNull);
    expect(event.tryEraserThickness(), isNull);
  });

  test('tryMoveLayerIndices accepts num values that are integral', () {
    final event = ActionCommitted(
      actionId: 'a4',
      type: ActionType.move,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{
        'sourceLayerIndex': 1.0,
        'targetLayerIndex': 3.0,
      },
    );

    expect(event.tryMoveLayerIndices(), (
      sourceLayerIndex: 1,
      targetLayerIndex: 3,
    ));
  });

  test('tryMoveLayerIndices rejects non-integral num values', () {
    final event = ActionCommitted(
      actionId: 'a5',
      type: ActionType.move,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{
        'sourceLayerIndex': 1.5,
        'targetLayerIndex': 3.0,
      },
    );

    expect(event.tryMoveLayerIndices(), isNull);
  });

  test('tryDrawStyle accepts num color values that are integral', () {
    final event = ActionCommitted(
      actionId: 'a6',
      type: ActionType.drawStroke,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{
        'tool': 'pen',
        'color': 1.0,
        'thickness': 3,
      },
    );

    expect(event.tryDrawStyle(), (tool: 'pen', colorArgb: 1, thickness: 3.0));
  });

  test('tryDrawStyle rejects non-integral num color values', () {
    final event = ActionCommitted(
      actionId: 'a7',
      type: ActionType.drawStroke,
      nodeIds: const ['n1'],
      timestampMs: 0,
      payload: const <String, Object?>{
        'tool': 'pen',
        'color': 1.5,
        'thickness': 3,
      },
    );

    expect(event.tryDrawStyle(), isNull);
  });
}
