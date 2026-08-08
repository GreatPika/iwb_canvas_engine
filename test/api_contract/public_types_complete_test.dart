import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
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

  test('public typedef bounds and named extensions are rejected', () async {
    final violations = await checkPublicTypesComplete(
      libraryPath:
          '$repositoryRoot/test/api_contract/fixtures/'
          'public_type_reference_violations.dart',
    );
    final message = violations.map((violation) => violation.message).join('\n');

    expect(message, contains('HiddenPublicBound'));
    expect(message, contains('exported named extension PublicStringAccessors'));
    expect(message, isNot(contains('ApprovedPublicBound')));
  });
}
