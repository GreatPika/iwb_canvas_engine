import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session resolver swap starts fresh cache', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resolver_swap_starts_fresh_cache_fixture.dart',
      ),
      completes,
    );
  });
}
