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

Future<void> runGuardrailsTool() async {
  final context = GuardrailContext.forCurrentDirectory();

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
    stderr.writeln('FAIL: guardrails');
    stderr.writeln('- ${failure.violation}');
    exit(1);
  }

  stdout.writeln('OK: guardrails');
}
