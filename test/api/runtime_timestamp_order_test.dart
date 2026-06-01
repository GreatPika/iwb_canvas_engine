import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime-created action timestamps are runtime-local and monotonic', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/api/fixtures/runtime_timestamp_order_fixture.dart',
      ),
      completes,
    );
  });
}
