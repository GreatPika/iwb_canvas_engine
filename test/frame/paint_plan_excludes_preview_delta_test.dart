import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('ordinary paint plans exclude preview values and deltas', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/paint_plan_excludes_preview_delta_fixture.dart',
      ),
      completes,
    );
  });
}
