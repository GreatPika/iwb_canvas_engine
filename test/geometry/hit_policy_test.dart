import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('geometry and hit policy behavior is executable', () async {
    await expectLater(
      runFlutterInPackageTest('test/geometry/fixtures/hit_policy_fixture.dart'),
      completes,
    );
  });
}
