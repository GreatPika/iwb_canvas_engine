import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime draw cleanup paths do not reserve timestamps', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/draw_cleanup_integration_fixture.dart',
      ),
      completes,
    );
  });
}
