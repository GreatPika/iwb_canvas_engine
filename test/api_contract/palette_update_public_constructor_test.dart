import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'public palette update constructor validates and preserves intent',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName: 'iwb_canvas_engine_palette_update_consumer',
          testFileName: 'palette_update_test.dart',
          testSource: _paletteUpdateTestSource,
        ),
        completes,
      );
    },
  );
}

const _paletteUpdateTestSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('presence distinguishes omitted and supplied empty fields', () {
    final absent = CanvasPaletteUpdate();
    final empty = CanvasPaletteUpdate(penColors: const []);
    final populated = CanvasPaletteUpdate(
      penColors: const [Color(0xFF010203)],
      backgroundColors: const [Color(0xFF040506)],
      gridSizes: const [12],
    );

    expect(absent.hasPenColors, isFalse);
    expect(absent.hasBackgroundColors, isFalse);
    expect(absent.hasGridSizes, isFalse);
    expect(absent.penColors, isEmpty);
    expect(absent.backgroundColors, isEmpty);
    expect(absent.gridSizes, isEmpty);
    expect(empty.hasPenColors, isTrue);
    expect(empty.penColors, isEmpty);
    expect(populated.hasPenColors, isTrue);
    expect(populated.hasBackgroundColors, isTrue);
    expect(populated.hasGridSizes, isTrue);
  });

  test('supplied collections are validated at construction', () {
    final overItems = List<Color>.filled(1025, const Color(0xFF000000));
    expectPaletteError(
      () => CanvasPaletteUpdate(penColors: overItems),
      CanvasDataErrorCode.maxItems,
      'palette.penColors',
    );
    expectPaletteError(
      () => CanvasPaletteUpdate(backgroundColors: overItems),
      CanvasDataErrorCode.maxItems,
      'palette.backgroundColors',
    );
    expectPaletteError(
      () => CanvasPaletteUpdate(gridSizes: List<double>.filled(1025, 1)),
      CanvasDataErrorCode.maxItems,
      'palette.gridSizes',
    );

    for (final double invalid in [double.nan, 0, -1, 10000001]) {
      expectPaletteError(
        () => CanvasPaletteUpdate(gridSizes: [invalid]),
        invalid.isNaN
            ? CanvasDataErrorCode.fieldMustBeFinite
            : CanvasDataErrorCode.fieldMustBePositive,
        'palette.gridSizes',
      );
    }
  });
}

void expectPaletteError(
  Object Function() create,
  CanvasDataErrorCode code,
  String path,
) {
  expect(
    create,
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', code)
          .having((error) => error.path, 'path', path),
    ),
  );
}
''';
