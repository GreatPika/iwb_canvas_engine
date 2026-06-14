import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('resource image cache accounts for decoded bytes', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resource_image_cache_memory_accounting_fixture.dart',
      ),
      completes,
    );
  });
}
