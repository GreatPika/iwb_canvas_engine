import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface painters clip main and overlay output to CustomPaint size', () {
    return expectLater(
      Future.wait([
        runFlutterInPackageTest(
          'test/surface/fixtures/main_painter_clipping_fixture.dart',
        ),
        runFlutterInPackageTest(
          'test/surface/fixtures/overlay_painter_clipping_fixture.dart',
        ),
      ]),
      completes,
    );
  });
}
