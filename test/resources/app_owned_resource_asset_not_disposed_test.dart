import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session leaves app-owned resource assets alive', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/app_owned_resource_asset_not_disposed_fixture.dart',
      ),
      completes,
    );
  });
}
