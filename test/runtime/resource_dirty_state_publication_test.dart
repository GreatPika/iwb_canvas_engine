import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('resource dirty calls publish resource visual state only', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/resource_dirty_state_publication_fixture.dart',
      ),
      completes,
    );
  });
}
