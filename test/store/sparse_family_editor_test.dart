import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('sparse family editor fixtures', () {
    return expectLater(
      runFlutterInPackageTests([
        'test/store/fixtures/sparse_family_editor_fixture.dart',
        'test/store/fixtures/sparse_family_editor_current_state_fixture.dart',
        'test/store/fixtures/sparse_family_editor_lifecycle_fixture.dart',
      ]),
      completes,
    );
  });
}
