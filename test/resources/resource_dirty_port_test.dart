import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('resource dirty port applies catalog no-op and acceptance rules', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resource_dirty_port_fixture.dart',
      ),
      completes,
    );
  });
}
