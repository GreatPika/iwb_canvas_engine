import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('surface resource session enforces resolver frame budget', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/resources/fixtures/resolver_frame_budget_fixture.dart',
      ),
      completes,
    );
  });
}
