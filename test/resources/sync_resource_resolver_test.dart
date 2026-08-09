import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'surface resource session resolves app resource assets synchronously',
    () {
      return expectLater(
        runFlutterInPackageTest(
          'test/resources/fixtures/sync_resource_resolver_fixture.dart',
        ),
        completes,
      );
    },
  );
}
