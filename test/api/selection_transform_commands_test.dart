import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'selection transform commands mutate eligible elements and emit actions',
    () {
      return expectLater(
        runFlutterInPackageTest(
          'test/api/fixtures/selection_transform_commands_fixture.dart',
        ),
        completes,
      );
    },
  );
}
