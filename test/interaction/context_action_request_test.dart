import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('context action request routing is executable', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/context_action_request_fixture.dart',
      ),
      completes,
    );
  });
}
