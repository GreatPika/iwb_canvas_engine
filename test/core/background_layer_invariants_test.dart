import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/background_layer_invariants.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';

void main() {
  test(
    'canonicalizeBackgroundLayerInvariants throws when callback does not throw',
    () {
      final layers = <Layer>[
        Layer(isBackground: true),
        Layer(isBackground: true),
      ];

      expect(
        () => canonicalizeBackgroundLayerInvariants(
          layers,
          onMultipleBackgroundError: (_) {},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('onMultipleBackgroundError must throw'),
          ),
        ),
      );
    },
  );
}
