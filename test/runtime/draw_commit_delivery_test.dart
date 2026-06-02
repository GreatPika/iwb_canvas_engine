import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime delivers draw commits through edit kernel', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/draw_commit_delivery_fixture.dart',
      ),
      completes,
    );
  });
}
