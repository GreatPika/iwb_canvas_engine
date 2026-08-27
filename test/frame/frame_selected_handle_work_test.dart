import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('main frame does not re-read captured selected handles', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/frame_selected_handle_work_fixture.dart',
      ),
      completes,
    );
  });
}
