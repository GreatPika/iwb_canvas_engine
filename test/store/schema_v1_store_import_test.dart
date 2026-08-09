import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('schema v1 import events prepare store-owned committed facts', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/schema_v1_store_import_fixture.dart',
      ),
      completes,
    );
  });
}
