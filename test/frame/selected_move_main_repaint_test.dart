import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selected move preview is routed to main repaint only', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/repaint_bus_output_fixture.dart',
      ),
      completes,
    );
  });
}
