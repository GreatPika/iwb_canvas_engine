import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('public document DTOs are projection-only', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/public_document_is_projection_only_fixture.dart',
      ),
      completes,
    );
  });
}
