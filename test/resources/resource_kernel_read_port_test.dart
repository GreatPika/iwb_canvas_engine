import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('resource kernel exposes catalog-backed public read port', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resource_kernel_read_port_fixture.dart',
      ),
      completes,
    );
  });
}
