import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('CanvasSurface interactive false isolates runtime state', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/interactive_false_state_isolation_fixture.dart',
      ),
      completes,
    );
  });
}
