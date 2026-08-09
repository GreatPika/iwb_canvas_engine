import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'application vector freshness and replacement lifecycle is executable',
    () {
      return expectLater(
        runFlutterInPackageTest(
          'test/resources/fixtures/application_vector_freshness_lifecycle_fixture.dart',
        ),
        completes,
      );
    },
  );
}
