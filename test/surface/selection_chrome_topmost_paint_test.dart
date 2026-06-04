import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('main painter paints selection chrome above records', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/selection_chrome_topmost_paint_fixture.dart',
      ),
      completes,
    );
  });
}
