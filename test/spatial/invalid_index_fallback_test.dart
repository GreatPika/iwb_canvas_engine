import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('spatial invalid-index fallback behavior is executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/spatial/fixtures/invalid_index_fallback_fixture.dart',
      ),
      completes,
    );
  });
}
