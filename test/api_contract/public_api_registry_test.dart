import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_registry.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  _testDiagnosticsSurface();
  _testInlineTextEditingSurface();
  _testDiagnosticsMembershipValidation();
}

void _testDiagnosticsSurface() {
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
}

void _testInlineTextEditingSurface() {
  test('inline text editing public surface has exactly the feature names', () {
    final publicExports = readPublicApiRegistry();
    final featureNames = {
      for (final name in publicExports)
        if (_isInlineTextEditingFeatureName(name)) name,
    };
    const inlineTextEditingNames = {
      'CanvasTextEditSession',
      'CanvasTextEditGeometry',
      'CanvasTextEditStyle',
      'CanvasTextEditingPort',
      'CanvasTextEditingOverlay',
    };

    expect(featureNames, inlineTextEditingNames);
    expect(publicExports, isNot(contains('CanvasTextEditCandidate')));
    expect(publicExports, isNot(contains('CanvasTextEditToken')));
  });
}

bool _isInlineTextEditingFeatureName(String name) {
  if (name == 'CanvasTextEditActionPayload') {
    return false;
  }

  return name.startsWith('CanvasTextEdit') ||
      name.startsWith('CanvasTextEditing');
}

void _testDiagnosticsMembershipValidation() {
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
