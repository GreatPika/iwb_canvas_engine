import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface interactive false routes no pointer events', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/interactive_false_pointer_routing_fixture.dart',
      ),
      completes,
    );
  });
}
