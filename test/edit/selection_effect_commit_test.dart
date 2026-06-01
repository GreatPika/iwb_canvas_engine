import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('edit commit delivery accepts selection effects and action intents', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/selection_effect_commit_fixture.dart',
      ),
      completes,
    );
  });
}
