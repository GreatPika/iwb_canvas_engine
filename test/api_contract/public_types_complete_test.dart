import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('public signatures reference exported or approved SDK types', () async {
    expect(await checkPublicTypesComplete(), isEmpty);
  });

  test('public declarations cannot inherit private surface types', () async {
    final violations = await checkPublicTypesComplete(
      libraryPath:
          '$repositoryRoot/test/api_contract/fixtures/private_supertypes.dart',
    );
    final message = violations.map((violation) => violation.message).join('\n');

    expect(message, contains('_HiddenBase'));
    expect(message, contains('_HiddenInterface'));
    expect(message, contains('_HiddenMixin'));
  });
}
