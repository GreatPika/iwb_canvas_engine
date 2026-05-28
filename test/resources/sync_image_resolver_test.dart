import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session resolves app images synchronously', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/sync_image_resolver_fixture.dart',
      ),
      completes,
    );
  });
}
