import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('ordinary paint plan cache writes are all-or-nothing', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart',
      ),
      completes,
    );
  });
}
