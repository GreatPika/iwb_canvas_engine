import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('resource dirty calls coordinate runtime delivery', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/resource_dirty_runtime_delivery_fixture.dart',
      ),
      completes,
    );
  });
}
