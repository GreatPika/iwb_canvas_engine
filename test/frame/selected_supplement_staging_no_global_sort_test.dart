import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selected move supplement stages after ordinary planning', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart',
      ),
      completes,
    );
  });
}
