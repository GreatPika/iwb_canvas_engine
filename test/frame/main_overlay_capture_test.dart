import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'main and overlay frame capture is immutable and preview-routed',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/frame/fixtures/main_overlay_capture_fixture.dart',
        ),
        completes,
      );
    },
  );
}
