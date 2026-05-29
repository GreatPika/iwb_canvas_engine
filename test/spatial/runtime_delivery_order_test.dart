import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime spatial delivery ordering is executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/spatial/fixtures/runtime_delivery_order_fixture.dart',
      ),
      completes,
    );
  });
}
