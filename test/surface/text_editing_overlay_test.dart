import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'public CanvasTextEditingOverlay edits through runtime sessions',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/surface/fixtures/text_editing_overlay_fixture.dart',
        ),
        completes,
      );
    },
  );
}
