import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('terminal eraser deletion is resolver-gated', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart',
      ),
      completes,
    );
  });
}
