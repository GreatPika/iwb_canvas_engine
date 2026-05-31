import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('frame painters consume immutable output only', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/no_live_runtime_read_in_painters_fixture.dart',
      ),
      completes,
    );
  });
}
