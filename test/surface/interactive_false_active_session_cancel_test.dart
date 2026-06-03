import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'CanvasSurface interactive false cancels active pointer session',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/surface/fixtures/interactive_false_active_session_cancel_fixture.dart',
        ),
        completes,
      );
    },
  );
}
