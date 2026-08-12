import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('sparse family editor owns one transaction lifecycle', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/sparse_family_editor_fixture.dart',
      ),
      completes,
    );
  });

  test('sparse family editor observes current rows for every decision', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/sparse_family_editor_current_state_fixture.dart',
      ),
      completes,
    );
  });

  test('sparse family editor normalizes before its single accepted freeze', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/sparse_family_editor_lifecycle_fixture.dart',
      ),
      completes,
    );
  });
}
