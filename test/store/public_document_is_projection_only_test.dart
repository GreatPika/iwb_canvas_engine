import 'package:test/test.dart';

import '../../tool/guardrails/src/store_projection_checks.dart';
import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('public document DTOs are projection-only', () async {
    expect(await checkNoPublicDocumentLiveState(), isEmpty);
    await expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/public_document_is_projection_only_fixture.dart',
      ),
      completes,
    );
  });
}
