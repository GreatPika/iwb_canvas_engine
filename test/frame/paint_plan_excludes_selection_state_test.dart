import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('ordinary paint plans exclude selection state and style', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/paint_plan_excludes_selection_state_fixture.dart',
      ),
      completes,
    );
  });
}
