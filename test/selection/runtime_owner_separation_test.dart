import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('selection owner is separate from document and projection state', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/selection/fixtures/runtime_owner_separation_fixture.dart',
      ),
      completes,
    );
  });
}
