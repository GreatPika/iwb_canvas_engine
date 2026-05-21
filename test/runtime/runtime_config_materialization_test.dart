import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'runtime materializes validated config values in package context',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/runtime/fixtures/runtime_config_materialization_fixture.dart',
        ),
        completes,
      );
    },
  );
}
