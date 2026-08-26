import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('mixed partial updates retain callback transaction atomicity', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/appearance_partial_updates_integration_fixture.dart',
      ),
      completes,
    );
  });
}
