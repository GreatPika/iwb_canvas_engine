import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('root public surface does not export retired public symbols', () async {
    expect(await checkNoRetiredPublicExports(), isEmpty);
  });

  test(
    'retired public exports are rejected from the current registry',
    () async {
      final violations = await checkNoRetiredPublicExports(
        libraryPath:
            '$repositoryRoot/test/api_contract/fixtures/'
            'retired_public_export_fixture.dart',
      );
      final message = violations
          .map((violation) => violation.message)
          .join('\n');

      expect(violations.single.guardrailId, 'api.no_retired_public_exports');
      expect(message, contains('Transform2D'));
      expect(message, isNot(contains('CanvasElement')));
    },
  );

  test('guardrail reads retired exports from the current registry', () {
    final source = File(
      '$repositoryRoot/tool/guardrails/src/public_api_checks.dart',
    ).readAsStringSync();

    expect(source, contains('readPublicApiRegistryData()'));
    expect(source, isNot(contains('public_api_symbols.txt')));
  });
}
