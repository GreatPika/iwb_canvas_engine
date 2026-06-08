import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test(
    'geometry committed handle order guardrail is registered and enforced',
    () async {
      expect(
        guardrailInventory(),
        contains(geometryCommittedHandleOrderGuardrailId),
      );
      expect(
        guardrailRouteFor(geometryCommittedHandleOrderGuardrailId),
        isNotNull,
      );
      expect(await checkCommittedHandleOrder(), isEmpty);

      final violations = checkCommittedHandleOrderSource(
        path: 'lib/src/geometry/bad.dart',
        content: 'final order = SceneNode().sceneOrder;',
      );
      expect(violations, hasLength(2));
      expect(
        violations.map((violation) => violation.guardrailId),
        everyElement(geometryCommittedHandleOrderGuardrailId),
      );
    },
  );
}
