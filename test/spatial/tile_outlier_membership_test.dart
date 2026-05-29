import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('tile and outlier membership behavior is executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/spatial/fixtures/tile_outlier_membership_fixture.dart',
      ),
      completes,
    );
  });
}
