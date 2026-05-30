import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('ordinary paint plan keys use next-owned revisions only', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/cache_keys_do_not_use_legacy_snapshot_shape_fixture.dart',
      ),
      completes,
    );
  });
}
