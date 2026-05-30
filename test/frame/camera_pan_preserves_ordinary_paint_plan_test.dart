import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('camera pan state does not invalidate ordinary paint plans', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/camera_pan_preserves_ordinary_paint_plan_fixture.dart',
      ),
      completes,
    );
  });
}
