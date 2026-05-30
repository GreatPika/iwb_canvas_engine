import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('frame caches expose bounded LRU policy probes', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/cache_capacity_eviction_policy_fixture.dart',
      ),
      completes,
    );
  });
}
