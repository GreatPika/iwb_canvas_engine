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
    expect(
      await _backgroundGridFixtureIsRejected(
        'final class PaintPlanKey { final int backgroundRevision; const PaintPlanKey(this.backgroundRevision); }',
      ),
      isTrue,
    );
  });

  test('ordinary record key camera fixture is rejected structurally', () async {
    expect(
      await _backgroundGridFixtureIsRejected(
        'final class OrdinaryPaintRecordKey { final int viewCameraRevision; const OrdinaryPaintRecordKey(this.viewCameraRevision); }',
      ),
      isTrue,
    );
  });
}

Future<bool> _backgroundGridFixtureIsRejected(String paintPlanSource) async {
  final violations = checkCacheBackgroundGridNotElementVisualSources({
    'lib/src/frame/paint_plan.dart': paintPlanSource,
  });
  final guardrailIds = violations
      .map((violation) => violation.guardrailId)
      .toSet();

  return guardrailIds.length == 1 &&
      guardrailIds.contains('cache.background_grid_not_element_visual') &&
      await guardrailRejectsStructuralViolations(
        id: 'cache.background_grid_not_element_visual',
        violations: violations,
      );
}
