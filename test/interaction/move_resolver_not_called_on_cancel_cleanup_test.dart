import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selected move cleanup paths do not call the resolver', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/move_machine_fixture.dart',
      ),
      completes,
    );
  });
}
