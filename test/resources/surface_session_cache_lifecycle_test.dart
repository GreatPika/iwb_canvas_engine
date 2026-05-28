import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session cache lifecycle is session-local', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/surface_session_cache_lifecycle_fixture.dart',
      ),
      completes,
    );
  });
}
