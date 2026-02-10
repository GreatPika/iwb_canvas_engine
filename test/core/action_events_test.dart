import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/action_events.dart';

void main() {
  group('ActionCommitted parsers', () {
    test('tryTransformDelta parses valid matrix payload', () {
      final action = ActionCommitted(
        actionId: 'a1',
        type: ActionType.transform,
        nodeIds: const <String>['n1'],
        timestampMs: 1,
        payload: <String, Object?>{
          'delta': <String, Object?>{
            'a': 1,
            'b': 0,
            'c': 0,
            'd': 1,
            'tx': 10,
            'ty': -5,
          },
        },
      );

      final delta = action.tryTransformDelta();
      expect(delta, isNotNull);
      expect(delta!.tx, 10);
      expect(delta.ty, -5);
    });

    test('tryTransformDelta returns null on invalid payload shapes', () {
      final noPayload = ActionCommitted(
        actionId: 'a',
        type: ActionType.transform,
        nodeIds: const <String>[],
        timestampMs: 0,
      );
      expect(noPayload.tryTransformDelta(), isNull);

      final nonMap = ActionCommitted(
        actionId: 'b',
        type: ActionType.transform,
        nodeIds: const <String>[],
        timestampMs: 0,
        payload: const <String, Object?>{'delta': 1},
      );
      expect(nonMap.tryTransformDelta(), isNull);

      final badKey = ActionCommitted(
        actionId: 'c',
        type: ActionType.transform,
        nodeIds: const <String>[],
        timestampMs: 0,
        payload: <String, Object?>{
          'delta': <Object?, Object?>{1: 2},
        },
      );
      expect(badKey.tryTransformDelta(), isNull);

      final badValue = ActionCommitted(
        actionId: 'd',
        type: ActionType.transform,
        nodeIds: const <String>[],
        timestampMs: 0,
        payload: const <String, Object?>{
          'delta': <String, Object?>{'a': 'x'},
        },
      );
      expect(badValue.tryTransformDelta(), isNull);
    });

    test('tryMoveLayerIndices supports int and integer-valued num only', () {
      final ok = ActionCommitted(
        actionId: 'a2',
        type: ActionType.move,
        nodeIds: const <String>[],
        timestampMs: 2,
        payload: const <String, Object?>{
          'sourceLayerIndex': 1.0,
          'targetLayerIndex': 3,
        },
      );
      final indices = ok.tryMoveLayerIndices();
      expect(indices, isNotNull);
      expect(indices!.sourceLayerIndex, 1);
      expect(indices.targetLayerIndex, 3);

      final bad = ActionCommitted(
        actionId: 'a3',
        type: ActionType.move,
        nodeIds: const <String>[],
        timestampMs: 3,
        payload: const <String, Object?>{
          'sourceLayerIndex': 1.5,
          'targetLayerIndex': 2,
        },
      );
      expect(bad.tryMoveLayerIndices(), isNull);
    });

    test('tryDrawStyle validates tool/color/thickness schema', () {
      final ok = ActionCommitted(
        actionId: 'a4',
        type: ActionType.drawLine,
        nodeIds: const <String>['n'],
        timestampMs: 4,
        payload: const <String, Object?>{
          'tool': 'line',
          'color': 0xFF112233,
          'thickness': 2,
        },
      );
      final style = ok.tryDrawStyle();
      expect(style, isNotNull);
      expect(style!.tool, 'line');
      expect(style.colorArgb, 0xFF112233);
      expect(style.thickness, 2.0);

      final badTool = ActionCommitted(
        actionId: 'a5',
        type: ActionType.drawLine,
        nodeIds: const <String>['n'],
        timestampMs: 5,
        payload: const <String, Object?>{'tool': 1, 'color': 1, 'thickness': 2},
      );
      expect(badTool.tryDrawStyle(), isNull);

      final badColor = ActionCommitted(
        actionId: 'a6',
        type: ActionType.drawLine,
        nodeIds: const <String>['n'],
        timestampMs: 6,
        payload: const <String, Object?>{
          'tool': 'line',
          'color': 1.5,
          'thickness': 2,
        },
      );
      expect(badColor.tryDrawStyle(), isNull);

      final badThickness = ActionCommitted(
        actionId: 'a7',
        type: ActionType.drawLine,
        nodeIds: const <String>['n'],
        timestampMs: 7,
        payload: const <String, Object?>{
          'tool': 'line',
          'color': 1,
          'thickness': '2',
        },
      );
      expect(badThickness.tryDrawStyle(), isNull);
    });

    test('tryEraserThickness reads numeric payload only', () {
      final ok = ActionCommitted(
        actionId: 'a8',
        type: ActionType.erase,
        nodeIds: const <String>['n'],
        timestampMs: 8,
        payload: const <String, Object?>{'eraserThickness': 7},
      );
      expect(ok.tryEraserThickness(), 7.0);

      final bad = ActionCommitted(
        actionId: 'a9',
        type: ActionType.erase,
        nodeIds: const <String>['n'],
        timestampMs: 9,
        payload: const <String, Object?>{'eraserThickness': '7'},
      );
      expect(bad.tryEraserThickness(), isNull);
    });
  });

  test('EditTextRequested stores payload as-is', () {
    const request = EditTextRequested(
      nodeId: 't',
      timestampMs: 42,
      position: Offset(3, 4),
    );

    expect(request.nodeId, 't');
    expect(request.timestampMs, 42);
    expect(request.position, const Offset(3, 4));
  });
}
