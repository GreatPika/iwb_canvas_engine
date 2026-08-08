import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';

void main() {
  test('geometry committed handle order guardrail rejects scene order', () {
    final violations = checkCommittedHandleOrderSource(
      path: 'lib/src/geometry/bad.dart',
      content: 'final order = SceneNode().sceneOrder;',
    );
    expect(violations, hasLength(2));
    expect(
      violations.map((violation) => violation.guardrailId),
      everyElement(geometryCommittedHandleOrderGuardrailId),
    );
  });
}
