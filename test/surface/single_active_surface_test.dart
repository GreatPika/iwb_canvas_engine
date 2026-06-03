import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface enforces one active surface per runtime', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/single_active_surface_fixture.dart',
      ),
      completes,
    );
  });
}
