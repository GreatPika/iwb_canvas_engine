import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('public grid update constructor validates scalar intent', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_grid_update_consumer',
        testFileName: 'grid_update_test.dart',
        testSource: _gridUpdateTestSource,
      ),
      completes,
    );
  });
}

const _gridUpdateTestSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('grid update preserves scalar presence', () {
    final absent = CanvasGridUpdate();
    final supplied = CanvasGridUpdate(
      enabled: true,
      cellSize: 12,
      color: const Color(0xFF010203),
    );

    expect(absent.enabled, isNull);
    expect(absent.cellSize, isNull);
    expect(absent.color, isNull);
    expect(supplied.enabled, isTrue);
    expect(supplied.cellSize, 12);
    expect(supplied.color, const Color(0xFF010203));
  });

  test('constructor rejects grid cell sizes invalid in every context', () {
    for (final invalid in <double>[double.nan, double.infinity, -1, 10000001]) {
      expectGridError(
        () => CanvasGridUpdate(cellSize: invalid),
        invalid.isNaN || invalid.isInfinite
            ? CanvasDataErrorCode.fieldMustBeFinite
            : CanvasDataErrorCode.fieldMustBeInRange,
      );
    }
  });
}

void expectGridError(Object Function() create, CanvasDataErrorCode code) {
  expect(
    create,
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', code)
          .having((error) => error.path, 'path', 'grid.cellSize'),
    ),
  );
}
''';
