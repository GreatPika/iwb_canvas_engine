import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface owns the active resource session lifecycle', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/surface_resource_session_lifecycle_fixture.dart',
      ),
      completes,
    );
  });
}
