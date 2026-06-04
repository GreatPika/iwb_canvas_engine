import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selection chrome does not add a surface-owned hit target', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/selection_chrome_hit_target_boundary_fixture.dart',
      ),
      completes,
    );
  });
}
