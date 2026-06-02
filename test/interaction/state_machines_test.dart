import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('interaction state machines cover eraser routing', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/state_machines_fixture.dart',
      ),
      completes,
    );
  });
}
