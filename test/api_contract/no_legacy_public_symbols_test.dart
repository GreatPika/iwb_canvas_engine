import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';

void main() {
  test('root public surface does not export retired legacy symbols', () async {
    expect(await checkNoLegacyPublicTypes(), isEmpty);
  });
}
