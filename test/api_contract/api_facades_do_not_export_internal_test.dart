import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('src api facades do not export internal declarations', () async {
    expect(await checkApiFacadesDoNotExportInternal(), isEmpty);
  });

  test('wide facade exports of internal declarations are rejected', () async {
    final violations = await checkApiFacadesDoNotExportInternal(
      facadePaths: [
        '$repositoryRoot/test/api_contract/fixtures/'
            'api_facade_internal_export.dart',
      ],
    );

    expect(
      violations.map((violation) => violation.guardrailId),
      everyElement('api.facades_do_not_export_internal'),
    );
    expect(violations.single.message, contains('leakedInternalHelper'));
  });
}
