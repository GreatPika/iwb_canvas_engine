import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('edit rollback preserves committed document and store facts', () {
    return expectLater(
      runFlutterInPackageTest('test/edit/fixtures/rollback_fixture.dart'),
      completes,
    );
  });
}
