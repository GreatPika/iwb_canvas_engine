import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('marquee overlay uses captured selection style', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/marquee_captured_style_fixture.dart',
      ),
      completes,
    );
  });
}
