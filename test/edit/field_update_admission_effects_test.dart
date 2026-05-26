import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('field update admission and effects are enforced', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/field_update_admission_effects_fixture.dart',
      ),
      completes,
    );
  });
}
