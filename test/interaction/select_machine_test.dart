import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('marquee state machine handles preview, commit, and cleanup', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/select_machine_fixture.dart',
      ),
      completes,
    );
  });
}
