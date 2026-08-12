import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('id admission cursor stays normalized at its owner seam', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/id_admission_cursor_fixture.dart',
      ),
      completes,
    );
  });
}
