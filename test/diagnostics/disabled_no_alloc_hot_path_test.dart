import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'disabled diagnostics do not allocate records on codec success',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/diagnostics/fixtures/disabled_no_alloc_hot_path_fixture.dart',
        ),
        completes,
      );
    },
  );
}
