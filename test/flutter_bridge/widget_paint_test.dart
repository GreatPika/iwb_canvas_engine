import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('public CanvasSurface hosts passive frame output', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/flutter_bridge/fixtures/widget_paint_fixture.dart',
      ),
      completes,
    );
  });
}
