import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_registry.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  const diagnosticsSurface = {
    'CanvasDiagnosticPolicy',
    'CanvasDiagnosticsDisabled',
    'CanvasDiagnosticsSummary',
    'CanvasDiagnosticsVerbose',
    'CanvasDataException',
    'CanvasDataErrorCode',
  };

  test('real registry exposes diagnostics public surface membership', () {
    final registry = readPublicApiRegistryFromYaml(
      File(
        '$repositoryRoot/docs/_registry/public_api_v1.yaml',
      ).readAsStringSync(),
    );

    expect(registry.diagnosticsPublicSurface, diagnosticsSurface);
    expect(
      registry.publicExports.containsAll(registry.diagnosticsPublicSurface),
      isTrue,
    );
  });

  test('diagnostics public surface entries must be public exports', () {
    expect(
      () => readPublicApiRegistryFromYaml('''
public_exports:
  - CanvasDataException
diagnostics_public_surface:
  - CanvasDataException
  - MissingDiagnosticsEntry
'''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('MissingDiagnosticsEntry'),
        ),
      ),
    );
  });
}
