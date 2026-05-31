import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('ordinary paint primitives apply opacity without saveLayer', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/ordinary_paint_primitive_policy_fixture.dart',
      ),
      completes,
    );
  });
}
