import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';

void main() {
  test('codec owners do not import runtime or mutation owners', () async {
    expect(await checkCodecNoRuntimeImports(), isEmpty);
  });
}
