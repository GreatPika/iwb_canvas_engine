import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'runtime dispose releases frame-owned static background picture',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/runtime/fixtures/frame_cache_dispose_fixture.dart',
        ),
        completes,
      );
    },
  );
}
