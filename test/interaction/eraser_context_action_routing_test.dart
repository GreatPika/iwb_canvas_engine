import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('eraser and context-action routing is executable', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/eraser_context_action_routing_fixture.dart',
      ),
      completes,
    );
  });
}
