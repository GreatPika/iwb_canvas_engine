import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_contract_checks.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('invalid public signature shapes are rejected structurally', () async {
    final violations = await checkPublicSignatureShape(
      libraryPath:
          '$repositoryRoot/test/api_contract/fixtures/'
          'public_signature_shape_violations.dart',
    );
    final message = violations.map((violation) => violation.message).join('\n');

    expect(
      violations.map((violation) => violation.guardrailId),
      everyElement('api.public_signature_shape'),
    );
    expect(message, contains('FutureOr<int>'));
    expect(message, contains('Future<int>?'));
    expect(message, contains('List<int>?'));
    expect(message, contains('dynamic'));
    expect(message, contains('Future<int>'));
  });
}
