import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface interactive false delegates draw cleanup', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/flutter_bridge/fixtures/interactive_false_pending_line_preserved_fixture.dart',
      ),
      completes,
    );
  });
}
