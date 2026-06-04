import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime text editing port lifecycle is executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/text_editing_port_fixture.dart',
      ),
      completes,
    );
  });
}
