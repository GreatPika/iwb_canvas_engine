import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session leaves app-owned images alive', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/app_owned_image_not_disposed_fixture.dart',
      ),
      completes,
    );
  });
}
