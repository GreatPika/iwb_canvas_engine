import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'paint asset binding delegates frame image resolution to session',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/frame/fixtures/paint_asset_binding_service_fixture.dart',
        ),
        completes,
      );
    },
  );
}
