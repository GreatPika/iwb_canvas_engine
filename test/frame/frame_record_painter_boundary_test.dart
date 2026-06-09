import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('frame record painter boundary', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/frame_record_painter_boundary_fixture.dart',
      ),
      completes,
    );
  });
}
