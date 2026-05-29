import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test(
    'geometry legacy scene order guardrail is registered and enforced',
    () async {
      expect(
        guardrailInventory(),
        contains(geometryNoLegacySceneOrderGuardrailId),
      );
      expect(
        guardrailRouteFor(geometryNoLegacySceneOrderGuardrailId),
        isNotNull,
      );
      expect(await checkNoLegacySceneOrder(), isEmpty);

      final violations = checkNoLegacySceneOrderSource(
        path: 'lib/src/geometry/bad.dart',
        content: 'final order = SceneNode().sceneOrder;',
      );
      expect(violations, hasLength(2));
      expect(
        violations.map((violation) => violation.guardrailId),
        everyElement(geometryNoLegacySceneOrderGuardrailId),
      );
    },
  );
}
