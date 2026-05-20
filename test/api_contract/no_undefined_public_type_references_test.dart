import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('root public signatures have no undefined public references', () async {
    expect(await checkNoUndefinedPublicTypeReferences(), isEmpty);
  });

  test('undefined public references use the dedicated P1 guardrail id', () async {
    final violations = await checkNoUndefinedPublicTypeReferences(
      libraryPath:
          '$repositoryRoot/test/api_contract/fixtures/'
          'public_type_reference_violations.dart',
    );

    expect(
      violations.map((violation) => violation.guardrailId),
      everyElement('api.no_undefined_public_type_references'),
    );
    expect(
      violations.map((violation) => violation.message).join('\n'),
      contains('HiddenPublicBound'),
    );
  });
}
