import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'CanvasSurfacePointerAdapter routes finite samples and terminal cleanup',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart',
        ),
        completes,
      );
    },
  );
}
