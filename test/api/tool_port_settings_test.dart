import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('tool port exposes settings cleanup and compatibility behavior', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/api/fixtures/tool_port_settings_fixture.dart',
      ),
      completes,
    );
  });
}
