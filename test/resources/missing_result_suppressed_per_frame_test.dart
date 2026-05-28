import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session suppresses unresolved results per frame', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/missing_result_suppressed_per_frame_fixture.dart',
      ),
      completes,
    );
  });
}
