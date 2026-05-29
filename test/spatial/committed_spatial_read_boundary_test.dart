import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('committed spatial read boundary exposes scope facts safely', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/spatial/fixtures/committed_spatial_read_boundary_fixture.dart',
      ),
      completes,
    );
  });
}
