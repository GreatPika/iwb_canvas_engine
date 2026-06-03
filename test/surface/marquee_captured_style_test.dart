import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface overlay painter uses captured marquee style', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/marquee_captured_style_fixture.dart',
      ),
      completes,
    );
  });
}
