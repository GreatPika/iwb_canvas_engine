import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('edit document and resource rows install through the store', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/edit_matrix_effects_fixture.dart',
      ),
      completes,
    );
  });
}
