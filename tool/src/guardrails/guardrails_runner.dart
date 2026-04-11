import 'dart:io';

import '../guardrail_support/guardrail_context.dart';
import 'contract_architecture_guardrails.dart';
import 'controller_api_guardrails.dart';
import 'interactive_api_guardrails.dart';
import 'model_architecture_guardrails.dart';
import 'mutable_type_leak_guardrails.dart';
import 'public_signature_hermeticity_guardrails.dart';
import 'public_surface_guardrails.dart';

Future<void> runGuardrailsTool() async {
  final context = GuardrailContext.forCurrentDirectory();

  try {
    final publicSurfaceResult = await runPublicSurfaceGuardrails(
      context: context,
    );
    _failIfNeeded(publicSurfaceResult.violations);

    final mutableTypeViolations = await runMutableTypeLeakGuardrails(
      context: context,
      exportedSurfaces: publicSurfaceResult.exportedSurfaces,
    );
    _failIfNeeded(mutableTypeViolations);

    final hermeticityViolations = await runPublicSignatureHermeticityGuardrails(
      context: context,
      exportedSurfaces: publicSurfaceResult.exportedSurfaces,
    );
    _failIfNeeded(hermeticityViolations);

    final interactiveViolations = await runInteractiveApiGuardrails(
      context: context,
    );
    _failIfNeeded(interactiveViolations);

    final controllerViolations = await runControllerApiGuardrails(
      context: context,
    );
    _failIfNeeded(controllerViolations);

    final modelArchitectureViolations = await runModelArchitectureGuardrails(
      context: context,
    );
    _failIfNeeded(modelArchitectureViolations);

    final contractArchitectureViolations =
        await runContractArchitectureGuardrails(context: context);
    _failIfNeeded(contractArchitectureViolations);
  } on _GuardrailFailure catch (failure) {
    stderr.writeln('FAIL: guardrails');
    stderr.writeln('- ${failure.violation}');
    exit(1);
  } on GuardrailToolFailure catch (failure) {
    stderr.writeln('FAIL: guardrails');
    stderr.writeln('- ${failure.violation}');
    exit(1);
  }

  stdout.writeln('OK: guardrails');
}

void _failIfNeeded(List<GuardrailViolation> violations) {
  if (violations.isEmpty) {
    return;
  }
  throw _GuardrailFailure(violations.first);
}

class _GuardrailFailure implements Exception {
  const _GuardrailFailure(this.violation);

  final GuardrailViolation violation;
}
