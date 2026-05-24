import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('typed edit effects avoid concrete downstream owner dependencies', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/typed_effects_no_frame_dependency_fixture.dart',
      ),
      completes,
    );
  });
}
