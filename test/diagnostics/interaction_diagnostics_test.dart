import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('P10 interaction diagnostics route internally', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/diagnostics/fixtures/interaction_diagnostics_fixture.dart',
      ),
      completes,
    );
  });
}
