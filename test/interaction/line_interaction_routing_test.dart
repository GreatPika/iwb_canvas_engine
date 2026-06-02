import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('line interaction routing is executable', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/line_interaction_routing_fixture.dart',
      ),
      completes,
    );
  });
}
