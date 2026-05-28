import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('mark-all dirty clears active session cache', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/mark_all_resources_dirty_session_invalidation_fixture.dart',
      ),
      completes,
    );
  });
}
