import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('preview exclusion guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'frame.paint_plan_excludes_preview_delta',
        suites: {'blocking', 'frame'},
        proofPaths: ['test/frame/paint_plan_excludes_preview_delta_test.dart'],
      ),
      isTrue,
    );
  });

  test('preview paint-plan key fixture is rejected structurally', () async {
    expect(
      await _previewFixtureIsRejected(
        'final class PaintPlanKey { final Object previewDelta; const PaintPlanKey(this.previewDelta); }',
      ),
      isTrue,
    );
  });

  test('preview paint-plan value fixture is rejected structurally', () async {
    expect(
      await _previewFixtureIsRejected(
        'final class PaintPlan { final Object selectedMovePreview; const PaintPlan(this.selectedMovePreview); }',
      ),
      isTrue,
    );
  });
}

Future<bool> _previewFixtureIsRejected(String paintPlanSource) async {
  final violations = checkPaintPlanExcludesPreviewDeltaSources({
    'lib/src/frame/paint_plan.dart': paintPlanSource,
  });
  final guardrailIds = violations
      .map((violation) => violation.guardrailId)
      .toSet();

  return guardrailIds.length == 1 &&
      guardrailIds.contains('frame.paint_plan_excludes_preview_delta') &&
      await guardrailRejectsStructuralViolations(
        id: 'frame.paint_plan_excludes_preview_delta',
        violations: violations,
      );
}
