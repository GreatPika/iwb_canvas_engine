import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('marquee preview is routed to overlay repaint only', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/repaint_bus_output_fixture.dart',
      ),
      completes,
    );
  });
}
