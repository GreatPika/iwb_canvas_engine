import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('render primitive cache snapshot exposes painter primitives', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/render_primitive_cache_snapshot_fixture.dart',
      ),
      completes,
    );
  });
}
