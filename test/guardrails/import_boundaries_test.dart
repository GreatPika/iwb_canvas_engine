import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';

void main() {
  test(
    'production source paths obey P0 import and retired-shape boundaries',
    () async {
      expect(await checkCoreBoundaries(), isEmpty);
    },
  );
}
