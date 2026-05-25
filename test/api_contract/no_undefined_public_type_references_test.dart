import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_checks.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('root public signatures have no undefined public references', () async {
    expect(await checkNoUndefinedPublicTypeReferences(), isEmpty);
  });

  test(
    'undefined public references use the dedicated P1 guardrail id',
    () async {
      final violations = await _fixtureViolations(
        fixtureName: 'public_type_reference_violations.dart',
      );

      expect(_guardrailIds(violations), _undefinedTypeReferenceIds);
      expect(_violationMessages(violations), contains('HiddenPublicBound'));
    },
  );

  test('public Flutter barrel types may resolve to src declarations', () async {
    expect(
      await _fixtureViolations(
        fixtureName: 'public_flutter_barrel_type_references.dart',
      ),
      isEmpty,
    );
  });

  test('Flutter src types outside approved barrels are rejected', () async {
    final violations = await _fixtureViolations(
      fixtureName: 'public_flutter_src_type_reference.dart',
    );

    expect(_guardrailIds(violations), _undefinedTypeReferenceIds);
    expect(_violationMessages(violations), contains('RawWebImage'));
  });
}

Future<List<GuardrailViolation>> _fixtureViolations({
  required String fixtureName,
}) {
  return checkNoUndefinedPublicTypeReferences(
    libraryPath: _fixturePath(fixtureName),
  );
}

Iterable<String> _guardrailIds(Iterable<GuardrailViolation> violations) {
  return violations.map((violation) => violation.guardrailId);
}

String _violationMessages(Iterable<GuardrailViolation> violations) {
  return violations.map((violation) => violation.message).join('\n');
}

String _fixturePath(String fixtureName) {
  return '$repositoryRoot/test/api_contract/fixtures/$fixtureName';
}

final _undefinedTypeReferenceIds = everyElement(
  'api.no_undefined_public_type_references',
);
