import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('overlay drawable policy renders accepted degenerate inputs', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/frame_drawable_overlay_policy_fixture.dart',
      ),
      completes,
    );
  });

  test('main drawable policy renders accepted degenerate inputs', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/frame_drawable_main_policy_fixture.dart',
      ),
      completes,
    );
  });
}
