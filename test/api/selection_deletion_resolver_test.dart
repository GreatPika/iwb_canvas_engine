import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test(
    'selection deletion preserves guarded callbacks and unified commit facts',
    () async {
      await expectLater(
        runFlutterInPackageTest(
          'test/api/fixtures/selection_deletion_resolver_fixture.dart',
        ),
        completes,
      );
      await expectLater(
        runFlutterInPackageTest(
          'test/api/fixtures/unified_delete_commit_fixture.dart',
        ),
        completes,
      );
    },
  );
}
