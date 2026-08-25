import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'selection deletion resolves the whole Store-backed set before commit',
    () {
      return expectLater(
        runFlutterInPackageTest(
          'test/api/fixtures/selection_deletion_resolver_fixture.dart',
        ),
        completes,
      );
    },
  );
}
