import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('load and dispose use interaction-owned cleanup', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/load_interaction_cleanup_fixture.dart',
      ),
      completes,
    );
  });
}
