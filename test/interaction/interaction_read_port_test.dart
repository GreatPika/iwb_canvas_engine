import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('interaction read port returns immutable committed facts', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/interaction/fixtures/interaction_read_port_fixture.dart',
      ),
      completes,
    );
  });
}
