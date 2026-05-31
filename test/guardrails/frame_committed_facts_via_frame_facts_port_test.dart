import 'package:test/test.dart';

import '../../tool/guardrails/src/core_boundary_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('frame facts boundary guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'frame.committed_facts_via_frame_facts_port',
        suites: {'blocking', 'frame'},
        proofPaths: [
          'test/guardrails/import_boundaries_test.dart',
          'test/frame/main_overlay_capture_test.dart',
          'test/frame/paint_asset_binding_service_test.dart',
        ],
      ),
      isTrue,
    );
  });

  test('frame session ownership fixture is rejected structurally', () async {
    final violations = checkCoreBoundaryFile(
      path: 'lib/src/frame/bad_session_owner.dart',
      content: "import '../resources/surface_resource_session.dart';\n",
    );

    expect(
      violations,
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'frame.committed_facts_via_frame_facts_port',
        ),
      ),
    );

    final result = await runGuardrailsWithProofRunner(
      ['frame.committed_facts_via_frame_facts_port'],
      runDartTest: (_, _) async => 0,
      violationChecks: {
        'frame.committed_facts_via_frame_facts_port': () async => violations,
      },
    );

    expect(result.exitCode, 1);
  });
}
