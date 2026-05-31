import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface camera pan updates captured frame output', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/flutter_bridge/fixtures/surface_camera_frame_output_fixture.dart',
      ),
      completes,
    );
  });
}
