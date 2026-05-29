import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('spatial stale candidate rejection is executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/spatial/fixtures/spatial_kernel_fixture.dart',
      ),
      completes,
    );
  });
}
