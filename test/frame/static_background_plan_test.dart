import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('static background cache identity is separate and bounded', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/static_background_plan_fixture.dart',
      ),
      completes,
    );
  });
}
