import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('runtime loadDocument publishes one atomic replacement state', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/load_document_state_publication_fixture.dart',
      ),
      completes,
    );
  });
}
