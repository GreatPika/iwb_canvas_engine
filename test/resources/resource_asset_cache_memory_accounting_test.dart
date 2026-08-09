import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('resource asset cache accounts for decoded image bytes', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resource_asset_cache_memory_accounting_fixture.dart',
      ),
      completes,
    );
  });
}
