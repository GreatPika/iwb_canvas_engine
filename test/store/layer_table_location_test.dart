import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'LayerTable locations stay exact and direct through owner lifecycles',
    () {
      return expectLater(
        runFlutterInPackageTest(
          'test/store/fixtures/layer_table_location_fixture.dart',
        ),
        completes,
      );
    },
  );
}
