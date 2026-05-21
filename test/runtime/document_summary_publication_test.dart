import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime summary is coherent with committed document facts', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/document_summary_publication_fixture.dart',
      ),
      completes,
    );
  });
}
