import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('unregistered root public export is rejected', () async {
    final violations = await checkPublicExportsComplete(
      libraryPath:
          '$repositoryRoot/test/api_contract/fixtures/'
          'unregistered_public_export_fixture.dart',
    );

    expect(violations, hasLength(1));
    expect(violations.single.guardrailId, 'api.public_exports_complete');
    expect(violations.single.message, contains('UnregisteredPublicExport'));
  });
}
