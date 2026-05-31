import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('overlay preview planner admits immutable overlay primitives', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/overlay_preview_admission_fixture.dart',
      ),
      completes,
    );
  });
}
