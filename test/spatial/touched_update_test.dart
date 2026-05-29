import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('spatial touched update behavior is executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/spatial/fixtures/touched_update_fixture.dart',
      ),
      completes,
    );
  });
}
