import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('grid updates preserve latest local grid intent', () {
    return expectLater(
      runFlutterInPackageTest('test/edit/fixtures/grid_update_fixture.dart'),
      completes,
    );
  });
}
