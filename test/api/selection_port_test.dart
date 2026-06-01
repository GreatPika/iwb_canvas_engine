import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selection port applies selection changes without user actions', () {
    return expectLater(
      runFlutterInPackageTest('test/api/fixtures/selection_port_fixture.dart'),
      completes,
    );
  });
}
