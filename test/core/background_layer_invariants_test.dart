import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/background_layer_invariants.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';

void main() {
  test('ensureBackgroundLayer creates background layer when missing', () {
    final scene = Scene(layers: <ContentLayer>[ContentLayer()]);

    final layer = ensureBackgroundLayer(scene);

    expect(scene.backgroundLayer, isNotNull);
    expect(identical(scene.backgroundLayer, layer), isTrue);
  });

  test('ensureBackgroundLayer returns existing layer without replacement', () {
    final existing = BackgroundLayer();
    final scene = Scene(
      backgroundLayer: existing,
      layers: <ContentLayer>[ContentLayer()],
    );

    final resolved = ensureBackgroundLayer(scene);

    expect(identical(resolved, existing), isTrue);
    expect(identical(scene.backgroundLayer, existing), isTrue);
  });
}
