import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('staged document load preparation and failure behavior', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/staged_document_load_success_failure_fixture.dart',
      ),
      completes,
    );
  });
}
