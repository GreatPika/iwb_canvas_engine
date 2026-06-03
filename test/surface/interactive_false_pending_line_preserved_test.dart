import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface interactive false preserves pending line state', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/interactive_false_pending_line_preserved_fixture.dart',
      ),
      completes,
    );
  });
}
