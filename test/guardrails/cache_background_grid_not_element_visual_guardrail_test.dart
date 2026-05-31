import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('background and grid cache guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'cache.background_grid_not_element_visual',
        suites: {'blocking', 'cache'},
        proofPaths: [
          'test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart',
          'test/frame/static_background_plan_test.dart',
        ],
      ),
      isTrue,
    );
  });

  test('ordinary key background fixture is rejected structurally', () async {
    final violations = checkCacheBackgroundGridNotElementVisualSources({
      'lib/src/frame/paint_plan.dart':
          'final class PaintPlanKey { final int backgroundRevision; const PaintPlanKey(this.backgroundRevision); }',
    });

    expect(violations.map((violation) => violation.guardrailId), {
      'cache.background_grid_not_element_visual',
    });
    expect(
      await guardrailRejectsStructuralViolations(
        id: 'cache.background_grid_not_element_visual',
        violations: violations,
      ),
      isTrue,
    );
  });
}
