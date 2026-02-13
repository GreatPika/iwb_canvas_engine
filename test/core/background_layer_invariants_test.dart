import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/background_layer_invariants.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';

void main() {
  test(
    'canonicalizeBackgroundLayerInvariants moves single background to index 0',
    () {
      final layers = <Layer>[
        Layer(isBackground: false),
        Layer(isBackground: true),
        Layer(isBackground: false),
      ];

      canonicalizeBackgroundLayerInvariants(
        layers,
        onMultipleBackgroundError: (_) => throw StateError('unexpected'),
      );

      expect(layers.first.isBackground, isTrue);
      expect(layers[1].isBackground, isFalse);
      expect(layers[2].isBackground, isFalse);
    },
  );

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
