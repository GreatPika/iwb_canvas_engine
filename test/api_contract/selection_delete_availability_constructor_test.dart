import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'public selection delete availability preserves legacy constructor defaults',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName:
              'iwb_canvas_engine_selection_delete_availability_consumer',
          testFileName: 'selection_delete_availability_constructor_test.dart',
          testSource: _selectionDeleteAvailabilityConstructorTestSource,
        ),
        completes,
      );
    },
  );
}

const _selectionDeleteAvailabilityConstructorTestSource = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('omitted any-deletable value falls back to all-deletable value', () {
    const allDeletable = CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: true,
    );
    const notAllDeletable = CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: false,
    );

    expect(allDeletable.hasAnySelectedElementDeletable, isTrue);
    expect(notAllDeletable.hasAnySelectedElementDeletable, isFalse);
  });
}
''';
