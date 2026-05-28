import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('target dirty evicts active session cache entry', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resource_dirty_session_invalidation_fixture.dart',
      ),
      completes,
    );
  });
}
