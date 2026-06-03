import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface overlay painter renders accepted degenerate inputs', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/overlay_drawable_policy_fixture.dart',
      ),
      completes,
    );
  });
}
