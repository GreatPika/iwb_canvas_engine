import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('projection cache builds only through explicit read paths', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/no_projection_hot_path_fixture.dart',
      ),
      completes,
    );
  });
}
