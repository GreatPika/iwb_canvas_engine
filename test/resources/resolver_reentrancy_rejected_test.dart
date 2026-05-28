import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime rejects reentrant mutations from resource resolvers', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resolver_reentrancy_rejected_fixture.dart',
      ),
      completes,
    );
  });
}
