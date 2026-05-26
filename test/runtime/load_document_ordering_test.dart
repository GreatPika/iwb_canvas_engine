import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('loadDocument preparation and success ordering are guarded', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/runtime/fixtures/load_document_ordering_fixture.dart',
      ),
      completes,
    );
  });
}
