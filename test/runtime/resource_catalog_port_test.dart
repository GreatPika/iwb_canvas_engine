import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime resource catalog port copies committed descriptors', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/resource_catalog_port_fixture.dart',
      ),
      completes,
    );
  });
}
