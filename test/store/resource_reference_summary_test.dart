import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('FamilyTables resource-reference summaries stay bounded and exact', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/resource_reference_summary_fixture.dart',
      ),
      completes,
    );
  });
}
