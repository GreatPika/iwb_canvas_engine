import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  _registerRunnerBackedTest();
  _registerRejectedFixtureTests();
  _registerAllowedFixtureTest();
}

void _registerRunnerBackedTest() {
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
}

void _registerRejectedFixtureTests() {
  for (final fixture in _previewForbiddenFixtures) {
    test('preview ${fixture.label} fixture is rejected structurally', () async {
      expect(
        await _previewFixtureIsRejected(
          path: fixture.path,
          source: fixture.source,
        ),
        isTrue,
      );
    });
  }
}

void _registerAllowedFixtureTest() {
  test('preview allowed ordinary cache fixtures pass structurally', () {
    expect(
      checkPaintPlanExcludesPreviewDeltaSources({
        'lib/src/frame/paint_plan.dart': '''
final class PaintPlanKey { final int structuralRevision; }
final class OrdinaryPaintRecordKey { final int generation; }
final class PaintPlan { final List<Object> ordinaryRecords; }
final class OrdinaryPaintRecordCacheEntry { final Object records; }
final class DebugSurface {
  final Object previewDelta;
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

const _previewForbiddenFixtures = [
  (
    label: 'paint-plan key',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlanKey { final Object previewDelta; const PaintPlanKey(this.previewDelta); }',
  ),
  (
    label: 'paint-plan value',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object selectedMovePreview; const PaintPlan(this.selectedMovePreview); }',
  ),
  (
    label: 'ordinary record key',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class OrdinaryPaintRecordKey { final Object previewDelta; const OrdinaryPaintRecordKey(this.previewDelta); }',
  ),
  (
    label: 'ordinary cache entry',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class OrdinaryPaintRecordCacheEntry { final Object selectedMovePreview; const OrdinaryPaintRecordCacheEntry(this.selectedMovePreview); }',
  ),
  (
    label: 'render record',
    path: 'lib/src/frame/render_element_record.dart',
    source:
        'final class RenderElementRecord { final Object previewDelta; const RenderElementRecord(this.previewDelta); }',
  ),
  (
    label: 'row payload',
    path: 'lib/src/frame/render_element_record.dart',
    source:
        'final class RenderElementRecord { final Object row; const RenderElementRecord(this.row); } final class StrokeRenderRow { final Object selectedMovePreview; const StrokeRenderRow(this.selectedMovePreview); }',
  ),
  (
    label: 'getter signature',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object _delta; const PaintPlan(this._delta); Object get selectedMovePreview => _delta; }',
  ),
  (
    label: 'method type signature',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object _delta; const PaintPlan(this._delta); PreviewDelta previewValue() => _delta as PreviewDelta; }',
  ),
  (
    label: 'field initializer',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object cached = selectedMovePreview; }',
  ),
  (
    label: 'getter body',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        'final class PaintPlan { final Object _cached; const PaintPlan(this._cached); Object get cached => previewDelta; }',
  ),
  (
    label: 'string key',
    path: 'lib/src/frame/paint_plan.dart',
    source:
        "final class PaintPlan { final Object cached = const {'previewDelta': 1}; }",
  ),
];

Future<bool> _previewFixtureIsRejected({
  required String path,
  required String source,
}) async {
  final violations = checkPaintPlanExcludesPreviewDeltaSources({path: source});
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
