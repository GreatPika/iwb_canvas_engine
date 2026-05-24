import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('ordinary P5 edits record exact touched ids and flags', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/exact_touched_invalidation_fixture.dart',
      ),
      completes,
    );
  });
}
