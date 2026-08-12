import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('FamilyTables membership probes authoritative family maps directly', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/family_tables_membership_fixture.dart',
      ),
      completes,
    );
  });
}
