import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('FamilyTables batch replacement copies only changed family maps', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/family_tables_batch_replacement_fixture.dart',
      ),
      completes,
    );
  });
}
