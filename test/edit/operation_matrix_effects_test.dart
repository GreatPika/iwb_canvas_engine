import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('P5 document and resource edit rows install through the store', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/operation_matrix_effects_fixture.dart',
      ),
      completes,
    );
  });
}
