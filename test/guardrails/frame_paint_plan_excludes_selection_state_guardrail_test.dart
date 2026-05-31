import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('selection exclusion guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'frame.paint_plan_excludes_selection_state',
        suites: {'blocking', 'frame'},
        proofPaths: [
          'test/frame/paint_plan_excludes_selection_state_test.dart',
        ],
      ),
      isTrue,
    );
  });

  test('selection paint-plan key fixture is rejected structurally', () async {
    expect(
      await _selectionFixtureIsRejected(
        'final class PaintPlanKey { final int selectionRevision; const PaintPlanKey(this.selectionRevision); }',
      ),
      isTrue,
    );
  });

  test('selection paint-plan value fixture is rejected structurally', () async {
    expect(
      await _selectionFixtureIsRejected(
        'final class PaintPlan { final Set<Object> selectedElementIds; const PaintPlan(this.selectedElementIds); }',
      ),
      isTrue,
    );
  });

  test(
    'selection ordinary record key fixture is rejected structurally',
    () async {
      expect(
        await _selectionFixtureIsRejected(
          'final class OrdinaryPaintRecordKey { final int selectionRevision; const OrdinaryPaintRecordKey(this.selectionRevision); }',
        ),
        isTrue,
      );
    },
  );
}

Future<bool> _selectionFixtureIsRejected(String paintPlanSource) async {
  final violations = checkPaintPlanExcludesSelectionStateSources({
    'lib/src/frame/paint_plan.dart': paintPlanSource,
  });
  final guardrailIds = violations
      .map((violation) => violation.guardrailId)
      .toSet();

  return guardrailIds.length == 1 &&
      guardrailIds.contains('frame.paint_plan_excludes_selection_state') &&
      await guardrailRejectsStructuralViolations(
        id: 'frame.paint_plan_excludes_selection_state',
        violations: violations,
      );
}
