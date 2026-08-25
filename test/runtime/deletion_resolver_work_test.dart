import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('deletion resolver work remains bounded at real public routes', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/deletion_resolver_work_fixture.dart',
      ),
      completes,
    );
  });
}
