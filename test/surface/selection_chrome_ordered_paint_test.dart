import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('main painter orders selection chrome with records', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/selection_chrome_ordered_paint_fixture.dart',
      ),
      completes,
    );
  });
}
