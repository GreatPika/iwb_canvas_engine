import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session contains ordinary resolver exceptions', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resolver_exception_placeholder_fixture.dart',
      ),
      completes,
    );
  });
}
