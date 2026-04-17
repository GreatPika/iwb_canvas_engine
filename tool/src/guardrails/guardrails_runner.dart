import 'dart:io';

import 'support/guardrail_context.dart';
import 'core/guardrail_runner_support.dart';
import 'core/guardrail_violation.dart';
import 'rules/contract/contract_architecture_rules.dart';
import 'rules/controller/write_only_mutation_rules.dart';
import 'rules/interactive/mutation_boundary_rules.dart';
import 'rules/model/model_architecture_rules.dart';
import 'rules/public/public_signature_rules.dart';
import 'rules/public/public_surface_rules.dart';
import '../tool_command_result.dart';

Future<ToolCommandResult> evaluateGuardrailsTool({Directory? root}) async {
  final context = GuardrailContext.forDirectory(root ?? Directory.current);

  try {
    final publicSurfaceResult = await runPublicSurfaceGuardrails(
      context: context,
    );
    failOnFirstViolation(publicSurfaceResult.violations);

    final hermeticityViolations = await runPublicSignatureHermeticityGuardrails(
      context: context,
      exportedSurfaces: publicSurfaceResult.exportedSurfaces,
    );
    failOnFirstViolation(hermeticityViolations);

    final interactiveViolations = await runInteractiveApiGuardrails(
      context: context,
    );
    failOnFirstViolation(interactiveViolations);

    final controllerViolations = await runControllerApiGuardrails(
      context: context,
    );
    failOnFirstViolation(controllerViolations);

    final modelArchitectureViolations = await runModelArchitectureGuardrails(
      context: context,
    );
    failOnFirstViolation(modelArchitectureViolations);

    final contractArchitectureViolations =
        await runContractArchitectureGuardrails(context: context);
    failOnFirstViolation(contractArchitectureViolations);
  } on GuardrailToolFailure catch (failure) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: guardrails\n- ${failure.violation}\n',
    );
  }

  return const ToolCommandResult(exitCode: 0, stdout: 'OK: guardrails\n');
}

Future<void> runGuardrailsTool({Directory? root}) async {
  final result = await evaluateGuardrailsTool(root: root);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}
