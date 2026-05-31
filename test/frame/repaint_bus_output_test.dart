import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'frame repaint outputs are derived from immutable frame output',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/frame/fixtures/repaint_bus_output_fixture.dart',
        ),
        completes,
      );
    },
  );
}
