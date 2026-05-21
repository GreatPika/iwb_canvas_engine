import 'package:test/test.dart';

import '../../tool/guardrails/src/store_projection_checks.dart';
import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('projection cache builds only through explicit read paths', () async {
    expect(await checkProjectionOnlyExplicitReadPaths(), isEmpty);
    await expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/no_projection_hot_path_fixture.dart',
      ),
      completes,
    );
  });
}
