import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('resource runtime delivery coordinates resource updates', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/resource_runtime_delivery_fixture.dart',
      ),
      completes,
    );
  });
}
