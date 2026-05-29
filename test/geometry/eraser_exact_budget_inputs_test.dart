import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('eraser exact budget input primitives are executable', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/geometry/fixtures/eraser_exact_budget_inputs_fixture.dart',
      ),
      completes,
    );
  });
}
