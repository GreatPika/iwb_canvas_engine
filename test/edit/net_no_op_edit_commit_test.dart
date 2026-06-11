import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('net no-op edit commits are delivery-silent', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/net_no_op_edit_commit_fixture.dart',
      ),
      completes,
    );
  });
  test('net no-op interaction commits skip augmentation', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/net_no_op_interaction_commit_fixture.dart',
      ),
      completes,
    );
  });
  test('accepted interaction commits use final store facts', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/accepted_interaction_commit_fixture.dart',
      ),
      completes,
    );
  });
}
