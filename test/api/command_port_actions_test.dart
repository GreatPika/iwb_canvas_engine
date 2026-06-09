import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('command port remove clear and text behavior is bounded', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/api/fixtures/command_port_actions_fixture.dart',
      ),
      completes,
    );
  });
}
