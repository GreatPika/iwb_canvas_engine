import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'frame measured text layout drives geometry and spatial bounds',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/frame/fixtures/measured_text_layout_fixture.dart',
        ),
        completes,
      );
    },
  );
}
