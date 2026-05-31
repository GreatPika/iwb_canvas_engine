import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selection decoration planning is separate and bounded', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/selection_decoration_plan_fixture.dart',
      ),
      completes,
    );
  });
}
