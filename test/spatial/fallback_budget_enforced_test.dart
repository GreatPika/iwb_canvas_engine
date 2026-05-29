import 'dart:io';

import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('spatial fallback budgets are enforced', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/spatial/fixtures/fallback_budget_enforced_fixture.dart',
      ),
      completes,
    );
  });

  test('spatial budget counters stay outside DiagnosticsHub', () {
    final source = File(
      'lib/src/geometry/spatial_budget_counters.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('DiagnosticsHub')));
    expect(source, isNot(contains('DiagnosticRecord')));
  });
}
