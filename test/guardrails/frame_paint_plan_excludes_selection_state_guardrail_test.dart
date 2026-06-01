import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  _registerRunnerBackedTest();
  _registerRejectedFixtureTests();
  _registerAllowedFixtureTest();
}

void _registerRunnerBackedTest() {
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
}

void _registerRejectedFixtureTests() {
  for (final fixture in _selectionForbiddenFixtures) {
    test(
      'selection ${fixture.label} fixture is rejected structurally',
      () async {
        expect(
          await _selectionFixtureIsRejected(
            path: fixture.path,
            source: fixture.source,
          ),
          isTrue,
        );
      },
    );
  }
}

void _registerAllowedFixtureTest() {
  test('selection allowed ordinary cache fixtures pass structurally', () {
    expect(
      checkPaintPlanExcludesSelectionStateSources({
        'lib/src/frame/paint_plan.dart': '''
final class PaintPlanKey { final int structuralRevision; }
final class OrdinaryPaintRecordKey { final int generation; }
final class PaintPlan { final List<Object> ordinaryRecords; }
final class OrdinaryPaintRecordCacheEntry { final Object records; }
final class DebugSurface {
  final Object selectionRevision;
  final Object label = 'class PaintPlan';
}
''',
        'lib/src/frame/render_element_record.dart':
            'final class RenderElementRecord { final int orderToken; }',
      }),
      isEmpty,
    );
  });
}

const _selectionForbiddenFixtures = [
  (
    label: 'paint-plan key',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlanKey { final int selectionRevision; const PaintPlanKey(this.selectionRevision); }',
  ),
  (
    label: 'paint-plan value',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Set<Object> selectedElementIds; const PaintPlan(this.selectedElementIds); }',
  ),
  (
    label: 'selected ids alias',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Set<Object> selectedIds; const PaintPlan(this.selectedIds); }',
  ),
  (
    label: 'ordinary record key',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class OrdinaryPaintRecordKey { final int selectionRevision; const OrdinaryPaintRecordKey(this.selectionRevision); }',
  ),
  (
    label: 'ordinary cache entry',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class OrdinaryPaintRecordCacheEntry { final int selectionRevision; const OrdinaryPaintRecordCacheEntry(this.selectionRevision); }',
  ),
  (
    label: 'render record',
    path: 'lib/src/frame/render_element_record.dart',
    source:
        'final class RenderElementRecord { final Set<Object> selectedElementIds; const RenderElementRecord(this.selectedElementIds); }',
  ),
  (
    label: 'selection flag',
    path: 'lib/src/frame/render_element_record.dart',
    source:
        'final class RenderElementRecord { final bool isSelected; const RenderElementRecord(this.isSelected); }',
  ),
  (
    label: 'row payload',
    path: 'lib/src/frame/render_element_record.dart',
    source:
        'final class RenderElementRecord { final Object row; const RenderElementRecord(this.row); } final class TextRenderRow { final int selectionRevision; const TextRenderRow(this.selectionRevision); }',
  ),
  (
    label: 'getter signature',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object _ids; const PaintPlan(this._ids); Object get selectedElementIds => _ids; }',
  ),
  (
    label: 'method parameter signature',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object _ids; const PaintPlan(this._ids); bool hasSelection(Object selectionRevision) => true; }',
  ),
  (
    label: 'field initializer',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object cached = selectedElementIds; }',
  ),
  (
    label: 'getter body',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object _cached; const PaintPlan(this._cached); Object get cached => selectionRevision; }',
  ),
  (
    label: 'string key',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        "final class PaintPlan { final Object cached = const {'selectionRevision': 1}; }",
  ),
];

Future<bool> _selectionFixtureIsRejected({
  required String path,
  required String source,
}) async {
  final violations = checkPaintPlanExcludesSelectionStateSources({
    path: source,
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
