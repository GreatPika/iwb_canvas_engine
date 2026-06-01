import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('interaction preview publishes only preview public state', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/preview_public_state_fixture.dart',
      ),
      completes,
    );
  });
}
