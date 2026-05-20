import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('root public surface does not export retired legacy symbols', () async {
    expect(await checkNoLegacyPublicTypes(), isEmpty);
  });

  test('legacy golden symbols outside the old subset are rejected', () async {
    final violations = await checkNoLegacyPublicTypes(
      libraryPath:
          '$repositoryRoot/test/api_contract/fixtures/'
          'legacy_public_symbol_exports.dart',
    );
    final message = violations.map((violation) => violation.message).join('\n');

    expect(message, contains('Transform2D'));
    expect(message, isNot(contains('CanvasElement')));
  });
}
