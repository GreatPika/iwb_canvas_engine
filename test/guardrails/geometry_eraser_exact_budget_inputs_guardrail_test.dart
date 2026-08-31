import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';

void main() {
  test('eraser exact budget guardrail rejects incomplete source shapes', () {
    final violations = checkGeometryEraserExactBudgetInputSources(
      geometryPath: 'lib/src/geometry/geometry_policy.dart',
      geometryContent: 'void partialErase() {}',
      hitPath: 'lib/src/geometry/hit_test_policy.dart',
      hitContent: 'bool hit() => true;',
    );
    expect(violations, hasLength(3));
    expect(
      violations.map((violation) => violation.guardrailId),
      everyElement(geometryEraserExactBudgetGuardrailId),
    );

    final payloadShapeViolations = checkGeometryEraserExactBudgetInputSources(
      geometryPath: 'lib/src/geometry/geometry_policy.dart',
      geometryContent: '''
EraserExactBudgetInputs eraserTerminalBudgetInputs() =>
    EraserExactBudgetInputs(candidateLimit: 1, exactCheckLimit: 1);
final class EraserExactBudgetInputs {
  EraserExactBudgetInputs({
    required this.candidateLimit,
    required this.exactCheckLimit,
    required this.candidateIds,
  });
  final int candidateLimit;
  final int exactCheckLimit;
  final List<CanvasElementId> candidateIds;
}
''',
      hitPath: 'lib/src/geometry/hit_test_policy.dart',
      hitContent: 'bool exactEraserHit() => true;',
    );
    expect(payloadShapeViolations, hasLength(1));
    expect(
      payloadShapeViolations.single.guardrailId,
      geometryEraserExactBudgetGuardrailId,
    );
  });
}
