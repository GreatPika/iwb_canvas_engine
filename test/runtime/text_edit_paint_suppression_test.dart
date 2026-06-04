import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('active text edit paint suppression is executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/text_edit_paint_suppression_fixture.dart',
      ),
      completes,
    );
  });
}
