import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('non-deletion public routes do not call the deletion resolver', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/api/fixtures/deletion_excluded_routes_fixture.dart',
      ),
      completes,
    );
  });
}
