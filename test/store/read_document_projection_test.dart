import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('readDocument returns committed DTO state through projection', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/store/fixtures/read_document_projection_fixture.dart',
      ),
      completes,
    );
  });
}
