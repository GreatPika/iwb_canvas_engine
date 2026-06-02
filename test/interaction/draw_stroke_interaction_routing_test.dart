import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('draw stroke interaction routing is executable', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/draw_stroke_interaction_routing_fixture.dart',
      ),
      completes,
    );
  });
}
