import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('field update nullable and rejected update semantics are enforced', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/field_update_nullable_semantics_fixture.dart',
      ),
      completes,
    );
  });
}
