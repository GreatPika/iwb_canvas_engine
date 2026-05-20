import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';

void main() {
  test(
    'root public barrel exports every registry name and no extras',
    () async {
      expect(await checkPublicExportsComplete(), isEmpty);
    },
  );
}
