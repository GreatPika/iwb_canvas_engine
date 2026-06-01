import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('command facts port exposes immutable runtime command facts', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/command_facts_port_fixture.dart',
      ),
      completes,
    );
  });
}
