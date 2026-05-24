import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('edit sessions are synchronous, non-nested, and stale-safe', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/sync_non_nested_async_stale_fixture.dart',
      ),
      completes,
    );
  });
}
