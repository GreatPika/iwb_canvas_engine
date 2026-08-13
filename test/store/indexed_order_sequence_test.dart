import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'IndexedOrderSequence preserves its admitted AVL, semantic, isolation, and work guarantees',
    () {
      return expectLater(
        runFlutterInPackageTest(
          'test/store/fixtures/indexed_order_sequence_fixture.dart',
        ),
        completes,
      );
    },
  );
}
