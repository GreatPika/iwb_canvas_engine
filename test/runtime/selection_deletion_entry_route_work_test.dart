import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selection deletion entry route has bounded Store work', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/selection_deletion_entry_route_work_fixture.dart',
      ),
      completes,
    );
  });
}
