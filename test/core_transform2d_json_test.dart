import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Transform2D JSON map round-trip preserves fields', () {
    const original = Transform2D(a: 1.5, b: 2, c: -3, d: 4.25, tx: 10, ty: -20);
    final decoded = Transform2D.fromJsonMap(original.toJsonMap());

    expect(decoded.a, original.a);
    expect(decoded.b, original.b);
    expect(decoded.c, original.c);
    expect(decoded.d, original.d);
    expect(decoded.tx, original.tx);
    expect(decoded.ty, original.ty);
  });

  test('Transform2D.fromJsonMap accepts ints', () {
    final decoded = Transform2D.fromJsonMap(<String, Object?>{
      'a': 1,
      'b': 0,
      'c': 0,
      'd': 1,
      'tx': 5,
      'ty': -7,
    });

    expect(decoded.a, 1.0);
    expect(decoded.d, 1.0);
    expect(decoded.tx, 5.0);
    expect(decoded.ty, -7.0);
  });

  test('Transform2D.fromJsonMap throws for invalid maps', () {
    expect(
      () => Transform2D.fromJsonMap(<String, Object?>{
        'a': 1,
        'b': 0,
        'c': 0,
        'd': 1,
        'tx': 5,
        'ty': 'oops',
      }),
      throwsArgumentError,
    );

    expect(
      () => Transform2D.fromJsonMap(<String, Object?>{
        'a': 1,
        'b': 0,
        'c': 0,
        'd': 1,
        'tx': 5,
      }),
      throwsArgumentError,
    );
  });

  test(
    'ActionCommitted.tryTransformDelta parses delta map and ignores junk',
    () {
      const delta = Transform2D(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6);
      final action = ActionCommitted(
        actionId: 'a1',
        type: ActionType.transform,
        nodeIds: const <NodeId>[],
        timestampMs: 0,
        payload: <String, Object?>{'delta': delta.toJsonMap()},
      );

      final parsed = action.tryTransformDelta();
      expect(parsed, isNotNull);
      expect(parsed!.a, delta.a);
      expect(parsed.b, delta.b);
      expect(parsed.c, delta.c);
      expect(parsed.d, delta.d);
      expect(parsed.tx, delta.tx);
      expect(parsed.ty, delta.ty);

      final badPayload = ActionCommitted(
        actionId: 'a2',
        type: ActionType.transform,
        nodeIds: const <NodeId>[],
        timestampMs: 0,
        payload: const <String, Object?>{'delta': 'oops'},
      );
      expect(badPayload.tryTransformDelta(), isNull);

      final invalidDeltaPayload = ActionCommitted(
        actionId: 'a3',
        type: ActionType.transform,
        nodeIds: const <NodeId>[],
        timestampMs: 0,
        payload: const <String, Object?>{
          'delta': <String, Object?>{
            'a': 1,
            'b': 0,
            'c': 0,
            'd': 1,
            'tx': 5,
            'ty': 'oops',
          },
        },
      );
      expect(invalidDeltaPayload.tryTransformDelta(), isNull);
    },
  );
}
