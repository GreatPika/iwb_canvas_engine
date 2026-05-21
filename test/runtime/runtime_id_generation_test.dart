import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime id generation is store-admission-backed', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/runtime_id_generation_fixture.dart',
      ),
      completes,
    );
  });
}
