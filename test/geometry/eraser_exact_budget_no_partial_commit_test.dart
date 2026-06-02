import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('eraser exact budget no-partial behavior is executable', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/geometry/fixtures/eraser_exact_budget_no_partial_commit_fixture.dart',
      ),
      completes,
    );
  });
}
