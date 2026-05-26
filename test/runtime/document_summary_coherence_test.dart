import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('document summary coherence matches committed document facts', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/document_summary_coherence_fixture.dart',
      ),
      completes,
    );
  });
}
