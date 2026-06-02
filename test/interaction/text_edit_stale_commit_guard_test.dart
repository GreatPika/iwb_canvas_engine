import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('text edit stale commit guard is executable', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart',
      ),
      completes,
    );
  });
}
