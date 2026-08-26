import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('appearance read returns coherent immutable committed state', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/appearance_read_fixture.dart',
      ),
      completes,
    );
  });
}
