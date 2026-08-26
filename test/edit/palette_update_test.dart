import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('palette updates preserve latest local palette intent', () {
    return expectLater(
      runFlutterInPackageTest('test/edit/fixtures/palette_update_fixture.dart'),
      completes,
    );
  });
}
