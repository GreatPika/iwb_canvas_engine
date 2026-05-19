import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';

void main() {
  test('production code declares exactly one RuntimeRoot', () {
    expect(checkSingleRuntimeRoot(), isEmpty);
  });
}
