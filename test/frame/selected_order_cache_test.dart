import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selected order cache is one bounded derived snapshot', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/selected_order_cache_fixture.dart',
      ),
      completes,
    );
  });
}
