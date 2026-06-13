import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface rejects unbounded layout constraints', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/canvas_surface_layout_constraints_fixture.dart',
      ),
      completes,
    );
  });
}
