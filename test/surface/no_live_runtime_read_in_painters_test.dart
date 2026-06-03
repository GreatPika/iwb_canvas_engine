import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface painters consume immutable frame output only', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/surface/fixtures/no_live_runtime_read_in_painters_fixture.dart',
      ),
      completes,
    );
  });
}
