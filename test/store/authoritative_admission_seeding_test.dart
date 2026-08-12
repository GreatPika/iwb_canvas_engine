import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('complete admission seeds directly from authoritative owners', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/authoritative_admission_seeding_fixture.dart',
      ),
      completes,
    );
  });
}
