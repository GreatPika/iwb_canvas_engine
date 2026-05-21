import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime read ports expose committed immutable facts', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/runtime_read_ports_fixture.dart',
      ),
      completes,
    );
  });
}
