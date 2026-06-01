import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('accepted internal command intents emit user actions after state', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/commands_emit_user_actions_fixture.dart',
      ),
      completes,
    );
  });
}
