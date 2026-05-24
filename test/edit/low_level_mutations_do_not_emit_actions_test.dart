import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('low-level CanvasEdit mutations do not emit action events', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/low_level_mutations_do_not_emit_actions_fixture.dart',
      ),
      completes,
    );
  });
}
