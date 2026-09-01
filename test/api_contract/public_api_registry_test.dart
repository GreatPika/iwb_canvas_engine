import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_registry.dart';

void main() {
  _testDiagnosticsMembershipValidation();
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
