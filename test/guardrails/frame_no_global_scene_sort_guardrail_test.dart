import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('global scene sort guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'frame.no_global_scene_sort',
        suites: {'blocking', 'frame'},
        proofPaths: [
          'test/frame/selected_supplement_staging_no_global_sort_test.dart',
        ],
      ),
      isTrue,
    );
  });

  test('global scene sort fixture is rejected structurally', () async {
    final violations = _sceneSortViolations('''
void bad(List<dynamic> records) {
  records.sort((a, b) => a.orderToken.compareTo(b.orderToken));
}
''');

    expect(_sceneSortGuardrailIds(violations), {'frame.no_global_scene_sort'});
    expect(await _sceneSortViolationsAreRunnerRejected(violations), isTrue);
  });

  test('non-scene local sort fixture is allowed structurally', () {
    final violations = checkFrameNoGlobalSceneSortSources({
      'lib/src/frame/local_debug_order.dart':
          'void ok(List<String> labels) { labels.sort(); }',
    });

    expect(violations, isEmpty);
  });

  test('order-token sort fixture is rejected regardless of variable name', () {
    final violations = _sceneSortViolations('''
void bad(List<dynamic> rows) {
  rows.sort((a, b) => a.orderToken.compareTo(b.orderToken));
}
''');

    expect(_sceneSortGuardrailIds(violations), {'frame.no_global_scene_sort'});
  });
}

List<GuardrailViolation> _sceneSortViolations(String source) {
  return checkFrameNoGlobalSceneSortSources({
    'lib/src/frame/bad_selected_supplement.dart': source,
  });
}

Set<String> _sceneSortGuardrailIds(List<GuardrailViolation> violations) {
  return violations.map((violation) => violation.guardrailId).toSet();
}

Future<bool> _sceneSortViolationsAreRunnerRejected(
  List<GuardrailViolation> violations,
) {
  return guardrailRejectsStructuralViolations(
    id: 'frame.no_global_scene_sort',
    violations: violations,
  );
}
