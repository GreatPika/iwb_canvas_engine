import '../../../tool/guardrails/src/guardrail_executor.dart';
import '../../../tool/guardrails/src/guardrail_registry.dart';
import '../../../tool/guardrails/src/guardrail_violation.dart';

Future<bool> guardrailIsRunnerBacked({
  required String id,
  required Set<String> suites,
  required List<String> proofPaths,
}) async {
  final entry = guardrailInventory()[id];
  final route = guardrailRouteFor(id);

  return entry != null &&
      entry.suites.containsAll(suites) &&
      route != null &&
      proofPaths.every(route.description.contains) &&
      await guardrailRejectsFailedProofPath(
        id: id,
        failedProofPath: proofPaths.first,
      );
}

Future<bool> guardrailRejectsFailedProofPath({
  required String id,
  required String failedProofPath,
}) async {
  final result = await runGuardrailsWithProofRunner([
    id,
  ], runDartTest: (_, path) async => path == failedProofPath ? 1 : 0);

  return result.exitCode == 1 && result.ranGuardrailIds.single == id;
}

Future<bool> guardrailRejectsStructuralViolations({
  required String id,
  required List<GuardrailViolation> violations,
}) async {
  final result = await runGuardrailsWithProofRunner(
    [id],
    runDartTest: (_, _) async => 0,
    violationChecks: {id: () async => violations},
  );

  return result.exitCode == 1 && result.ranGuardrailIds.single == id;
}
