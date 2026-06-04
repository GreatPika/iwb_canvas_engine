import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'selected move preview stays continuous across coordinate sweep',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/frame/fixtures/selected_move_preview_coordinate_sweep_fixture.dart',
        ),
        completes,
      );
    },
  );
}
